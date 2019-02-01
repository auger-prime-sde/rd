library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- module to interface with an SPI flash
-- in particular the SST26VF032B
-- Note 1: the MSCK pin is connected to the flash chip cannot be
-- mapped in a user program. Instead a module named "USRMCLK" is instantiated
-- which forwards our desired clock signal. All other SPI pins must be mapped
-- via the normal pin assignment procedure to the correct pins.
--
--Note 2: To interface with the spi flash we need to write data at the falling
-- edge and read it at the rising edge. For that purpose the spi clock speed
-- will be half the i_clk speed.
--
-- Architecture note:
-- Flash operations that need to be implemented:
-- get chip and manufacturer id
-- get unique flash id (0x88)
-- (set unique flash id?)
-- read a page (0x03)
-- write a page (0x06, wait, 0x20, wait, 0x02)
-- optionally:
-- reset flash (0x66 ; 0x66)
-- read status and configuration registers (0x05 and 0x35)
--
-- Note 3: The spi flash chip has a 22 bits address space (32Mbit = 4MBytes = 2^22)
-- The bytes are arranged in blocks of 4096 bytes so the first 10 bits of the address
-- indicates the page/block number and the last 12 bytes indicate the byte
-- within the page. During page read/write the data line is used to communicate
-- the disired page so this needs 10 bits. During buffer read/write the address
-- line is used to set the address within the page so this requires 12 bits.
-- The data line is used to hold 8 bits while writing to the buffer. The upper
-- 2 bits are ignored in that situation.



entity flash_controller is
  port (
    -- clock:
    i_clk           : in std_logic;
    -- SPI interface:
    i_flash_miso    : in std_logic;
    o_flash_mosi    : out std_logic := '0';
    o_flash_ce      : out std_logic := '1';
    -- housekeeping interface:
    i_enable        : in std_logic;
    i_command       : in std_logic_vector(3 downto 0);
    i_address       : in std_logic_vector(11 downto 0);
    i_data          : in std_logic_vector(9 downto 0);
    o_busy          : out std_logic := '1';
    o_data          : out std_logic_vector(23 downto 0) := (others=>'Z')
    );
end flash_controller;





architecture behave of flash_controller is
  -- constants that describe the bus sizes: (not generic because caller should
  -- not attempt to change at will)
  constant NUM_COMMANDS : natural := 10;
  constant ADDR_BITS : natural := 12;
  constant INPUT_BITS : natural := 10;
  constant OUTPUT_BITS : natural := 8;
  
  -- constants for controlling this unit:
  -- constant CMD_GET_CHIP_INFO : std_logic_vector(CMD_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(16#1#,CMD_WIDTH));
  -- constant CMD_GET_UNIQ_ID   : std_logic_vector(CMD_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(16#2#,CMD_WIDTH));
  -- constant CMD_SET_UNIQ_ID   : std_logic_vector(CMD_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(16#3#,CMD_WIDTH));
  -- constant CMD_LOAD_PAGE     : std_logic_vector(CMD_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(16#4#,CMD_WIDTH));
  -- constant CMD_FLUSH_PAGE    : std_logic_vector(CMD_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(16#5#,CMD_WIDTH));
  -- constant CMD_WRITE_BUFFER  : std_logic_vector(CMD_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(16#6#,CMD_WIDTH));
  -- constant CMD_READ_BUFFER   : std_logic_vector(CMD_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(16#7#,CMD_WIDTH));
  -- constant CMD_RESET         : std_logic_vector(CMD_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(16#8#,CMD_WIDTH));
  -- constant CMD_GET_STATUS    : std_logic_vector(CMD_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(16#9#,CMD_WIDTH));
  -- constant CMD_GET_CONFIG    : std_logic_vector(CMD_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(16#a#,CMD_WIDTH));

  constant CMD_IDLE          : unsigned(3 downto 0) := X"0";
  constant CMD_GET_CHIP_INFO : unsigned(3 downto 0) := X"1";
  constant CMD_GET_UNIQ_ID   : unsigned(3 downto 0) := X"2";
  constant CMD_SET_UNIQ_ID   : unsigned(3 downto 0) := X"3";
  constant CMD_LOAD_PAGE     : unsigned(3 downto 0) := X"4";
  constant CMD_FLUSH_PAGE    : unsigned(3 downto 0) := X"5";
  constant CMD_WRITE_BUFFER  : unsigned(3 downto 0) := X"6";
  constant CMD_READ_BUFFER   : unsigned(3 downto 0) := X"7";
  constant CMD_RESET         : unsigned(3 downto 0) := X"8";
  constant CMD_GET_STATUS    : unsigned(3 downto 0) := X"9";
  constant CMD_GET_CONFIG    : unsigned(3 downto 0) := X"A";
  
  -- constant for sending to the SPI flash:
  constant SPI_WRITE_PAGE   : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(16#02#,8));
  constant SPI_READ_PAGE    : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(16#03#,8));
  constant SPI_ERASE_BLOCK  : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(16#04#,8));
  constant SPI_GET_STATUS   : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(16#05#,8));
  constant SPI_WRITE_ENABLE : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(16#06#,8));
  constant SPI_GET_CONFIG   : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(16#35#,8));
  constant SPI_RESET_ENBL   : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(16#66#,8));
  constant SPI_READ_SEC_ID  : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(16#88#,8));
  constant SPI_RESET        : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(16#99#,8));
  constant SPI_JEDEC_ID     : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(16#9F#,8));
  constant SPI_WRITE_SEC_ID : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(16#A5#,8));

 
  -- since the progression of each command is slightly different we'll need
  -- separate state machines to track each command:
  type t_Chip_Info_State    is (s_CI_Idle, s_CI_Cmd, s_CI_PhaseShift, s_CI_Data);
  type t_Get_Uniq_Id_State  is (s_GI_None);
  type t_Set_Uniq_Id_State  is (s_SI_None);
  type t_Load_Page_State    is (s_LP_Idle, s_LP_Cmd, s_LP_Addr, s_LP_PhaseShift, s_LP_Data);
  type t_Flush_Page_State   is (s_FP_Idle, s_FP_EnableWrite, s_FP_ClearPage, s_FP_WaitClear, s_FP_WriteCmd, s_FP_WriteData, s_FP_s_FP_WaitWrite);
  type t_Write_Buffer_State is (s_WB_Idle, s_WB_Busy);
  type t_Read_Buffer_State  is (s_RB_Idle, s_RB_Busy);
  type t_Reset_State        is (s_RS_Idle, s_RS_Enable, s_RS_Reset);
  type t_Get_Status_State   is (s_GS_Idle, s_GS_Cmd, s_GS_PhaseShift, s_GS_Data);
  type t_Get_Config_State   is (s_GC_Idle, s_GC_Cmd, s_GC_PhaseShift, s_GC_Data);

  
  component data_buffer
    generic (g_DATA_WIDTH, g_ADDRESS_WIDTH : natural);
    port (
      i_write_clk   : in  std_logic;
      i_write_enable: in  std_logic;
      i_write_addr  : in  std_logic_vector(g_ADDRESS_WIDTH-1 downto 0);
      i_write_data  : in  std_logic_vector(g_DATA_WIDTH-1 downto 0);
      i_read_clk    : in  std_logic;
      i_read_enable : in  std_logic;
      i_read_addr   : in  std_logic_vector(g_ADDRESS_WIDTH-1 downto 0);
      o_read_data   : out std_logic_vector(g_DATA_WIDTH-1 downto 0)
    );
  end component;


  

   -- variable that tells which state machine is active:
  signal r_command : unsigned(3 downto 0) := CMD_IDLE;
 
  
  -- signals for the write part:
  signal r_Chip_Info_State   : t_Chip_Info_State    := s_CI_Idle;
  signal r_Get_Uniq_Id_State : t_Get_Uniq_Id_State  := s_GI_None;
  signal r_Set_Uniq_Id_State : t_Set_Uniq_Id_State  := s_SI_None;
  signal r_Load_Page_State   : t_Load_Page_State    := s_LP_Idle;
  signal r_Flush_Page_State  : t_Flush_Page_State   := s_FP_Idle;
  signal r_Write_Buffer_Stat : t_Write_Buffer_State := s_WB_Busy;
  signal r_Read_Buffer_State : t_Read_Buffer_State  := s_RB_Busy;
  signal r_Reset_State       : t_Reset_State        := s_RS_Idle;
  signal r_Get_Status_State  : t_Get_Status_State   := s_GS_Idle;
  signal r_Get_Config_State  : t_Get_Config_State   := s_GC_Idle;


  -- counters are re-used in different states
  signal r_Count : natural range 0 to 10 := 0;
  signal r_WordCount : natural range 0 to 256 := 0;
  signal r_BitCount : natural range 0 to 7 := 0;


  -- signals to/from buffers
  signal r_read_buffer_read_enable : std_logic := '0';
  signal r_read_buffer_write_enable : std_logic := '0';
  signal r_read_buffer_data : std_logic_vector(INPUT_BITS-1 downto 0) := (others => 'Z');
  signal r_read_buffer_addr : std_logic_vector(ADDR_BITS-1 downto 0) := (others => 'Z');
  
  -- two signals used to communicate between read and write process
  --signal r_write_done : std_logic := '0';
  signal r_read_done : std_logic := '0';

  -- debug signals:
  --signal r_countdebug : std_logic_vector(7 downto 0) := (others=>'0');
  --signal state_is_idle, state_is_addr, state_is_data : std_logic;
  
  
begin

  write_buffer : data_buffer
    generic map (g_ADDRESS_WIDTH => 12, g_DATA_WIDTH => 8)
    port map (
      i_write_clk    => i_clk,
      i_write_enable => '0',
      i_write_addr   => i_address,
      i_read_clk     => i_clk,
      i_read_enable  => '1',
      i_read_addr    => (others => '0'),
      i_write_data   => i_data(7 downto 0),
      o_read_data    => open
      );

  read_buffer : data_buffer
    generic map (g_ADDRESS_WIDTH => 12, g_DATA_WIDTH => 8)
    port map (
      i_write_clk    => i_clk,
      i_write_enable => '0',
      i_write_addr   => (others => '0'),
      i_read_clk     => i_clk,
      i_read_enable  => '1',
      i_read_addr    => i_address,
      i_write_data   => (others => '0'),
      o_read_data    => o_data(7 downto 0)
      );


  
  --r_countdebug <= std_logic_vector(to_unsigned(r_count, 8));
  --state_is_idle <= '1' when r_State = s_Idle else '0';
  --state_is_addr <= '1' when r_State = s_Addr else '0';
  --state_is_data <= '1' when r_State = s_Data else '0';
  
  
  -- main read process
  p_read : process (i_clk) is
  begin
    if rising_edge(i_clk) then
      case r_Command is
        --------------------------------------------------------
        when CMD_IDLE =>
          -- only accept commands when idle
          if i_enable = '1' then
            r_Command <= unsigned(i_command);
          end if;
        --------------------------------------------------------
        when CMD_GET_CHIP_INFO =>
          case r_Chip_Info_State is
            when s_CI_Idle =>
              r_WordCount <= 0;
              r_BitCount <= 0;
              r_read_done <= '0';
            when s_CI_Cmd  =>
            when s_CI_PhaseShift =>
            when s_CI_Data =>
              -- read a bit
              o_data(23 - r_BitCount) <= i_flash_miso;
              r_BitCount <= r_BitCount + 1;
              if r_BitCount = 23 then
                r_read_done <= '1';
              end if;
          end case;
        --------------------------------------------------------  
        when CMD_GET_UNIQ_ID =>

        --------------------------------------------------------
        when CMD_SET_UNIQ_ID =>

        --------------------------------------------------------
        when CMD_LOAD_PAGE =>
          case r_Load_Page_State is
            when s_LP_Idle =>
              r_BitCount <= 0;
              r_WordCount <= 0;
              r_read_done <= '0';
            when s_LP_Cmd =>
            when s_LP_Addr =>
            when s_LP_PhaseShift =>
            when s_LP_Data =>
              
          end case;
        --------------------------------------------------------
        when CMD_FLUSH_PAGE =>

        --------------------------------------------------------
        when CMD_WRITE_BUFFER =>

        --------------------------------------------------------
        when CMD_READ_BUFFER =>

        --------------------------------------------------------
        when CMD_RESET =>

        --------------------------------------------------------
        when CMD_GET_STATUS =>

        --------------------------------------------------------
        when CMD_GET_CONFIG =>

        --------------------------------------------------------
        when others =>
          null;
        --######################################################
      end case;
    end if;    
  end process;
  

  -- main write process
  p_write : process (i_clk) is
  begin
    if falling_edge(i_clk) then
      case r_Command is
        ---------------------------------------------------------
        when CMD_IDLE =>
        -- nothing to do, trigger is received by rising edge process
        ---------------------------------------------------------
        when CMD_GET_CHIP_INFO =>
          case r_Chip_Info_State is
            when s_CI_Idle =>
              --o_flash_ce <= '1';
              o_busy <= '1';
              r_Chip_Info_State <= s_CI_Cmd;
              r_Count <= 0;
            when s_CI_Cmd =>
              o_flash_ce <= '0';
              o_flash_mosi <= SPI_JEDEC_ID(7-r_Count);
              r_Count <= (r_Count + 1) mod 8;
              if r_Count = 7 then
                r_Chip_Info_State <= s_CI_PhaseShift;
              end if;
            when s_CI_PhaseShift =>
              r_Chip_Info_State <= s_CI_Data;
              -- TODO: test with and without pragma translate_off 
              o_flash_mosi <= 'Z';
            when s_CI_Data =>
              if r_read_done = '1' then
                r_Chip_Info_State <= s_CI_Idle;
                o_busy <= '0';
                o_flash_ce <= '1';
                -- r_Command <= CMD_IDLE; TODO: figure out how to get r_command
                -- back to idle
              end if;
          end case;
        --#######################################################--
        when CMD_GET_UNIQ_ID =>
          
        --#######################################################--     
        when CMD_SET_UNIQ_ID =>
          
        --#######################################################--
        when CMD_LOAD_PAGE =>
          case r_Load_Page_State is
            when s_LP_Idle =>
              o_busy <= '1';
              r_Load_Page_State <= s_LP_Addr;
              r_Count <= 0;
            when s_LP_Cmd =>
              o_flash_ce <= '0';
              o_flash_mosi <= SPI_READ_PAGE(7-r_Count);
              r_Count <= (r_Count + 1) mod 8;
              if r_Count = 7 then
                r_Load_Page_State <= s_LP_Addr;
                r_Count <= 0; -- is this necessary?
              end if;
            when s_LP_Addr =>
              -- there are 24 address bits. The first 2 are not used and shoud
              -- be 0. The next 10 should be taken from i_data and signal the
              -- page number. The last 12 should be 0 again and signal the
              -- address within the page in case you want to start reading mid-page.
              if r_Count > 1 and r_Count <= 11 then
                o_flash_mosi <= i_data(r_Count - 2);
              else
                o_flash_mosi <= '0';
              end if;
              r_Count <= (r_Count + 1) mod 24;
              if r_Count = 23 then
                r_Load_Page_State <= s_LP_PhaseShift;
              end if;
            when s_LP_PhaseShift =>
              o_flash_mosi <= 'Z';
              r_Load_Page_State <= s_LP_Data;
            when s_LP_Data =>
              if r_read_done = '1' then
                r_Load_Page_State <= s_LP_Idle;
                o_busy <= '0';
                o_flash_ce <= '1';
              end if;
          end case;
          
        --######################################################--
        when CMD_FLUSH_PAGE =>

        ---------------------------------------------------------
        when CMD_WRITE_BUFFER =>

        ---------------------------------------------------------
        when CMD_READ_BUFFER =>

        ---------------------------------------------------------
        when CMD_RESET =>

        ---------------------------------------------------------
        when CMD_GET_STATUS =>

        ---------------------------------------------------------
        when CMD_GET_CONFIG =>

        ---------------------------------------------------------
        when others =>
          r_Command <= CMD_IDLE;
        --#####################################################--
      end case;
    end if;
  end process;

end behave;

