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


entity flash_controller is
  port (
    -- clock:
    i_clk           : in std_logic;
    -- SPI interface:
    i_spi_miso      : in std_logic;
    o_spi_mosi      : out std_logic := '0';
    o_spi_ce        : out std_logic := '1';
    -- housekeeping interface:
    i_enable        : in std_logic;
    i_command       : in std_logic_vector(3 downto 0);
    i_address       : in std_logic_vector(23 downto 0);
    i_data          : in std_logic_vector(9 downto 0);
    o_busy          : out std_logic := '1';
    o_data          : out std_logic_vector(7 downto 0) := (others=>'z');
    );
end flash_controller;





architecture behave of flash_controller is
  -- constant:
  constant CMD_JEDEC_ID : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(16#9F#,8));
  -- state machine type:
  type t_State is (s_Idle, s_Addr, s_PhaseShift, s_Data); -- phaseshift state
                                                          -- only used when
                                                          -- issuing read commands

  -- signals for the write part:
  signal r_State : t_State := s_Idle;
  signal r_Count : natural range 0 to 7 := 0;
  -- signal r_WriteWordCount : natural range 0 to 255;

  --signals for the read part:
  signal r_WordCount : natural range 0 to 256 := 0;
  signal r_BitCount : natural range 0 to 7 := 0;
  
  -- two signals used to communicate between read and write process
  signal r_addr_ready : std_logic := '0';
  signal r_read_done : std_logic := '0';

  -- debug signals:
  signal r_countdebug : std_logic_vector(7 downto 0) := (others=>'0');
  signal state_is_idle, state_is_addr, state_is_data : std_logic;
  
  
begin

  r_countdebug <= std_logic_vector(to_unsigned(r_count, 8));
  state_is_idle <= '1' when r_State = s_Idle else '0';
  state_is_addr <= '1' when r_State = s_Addr else '0';
  state_is_data <= '1' when r_State = s_Data else '0';
  
  
  -- main read process
  p_read : process (i_clk) is
  begin
    if rising_edge(i_clk) then
      case r_State is
        when s_Idle =>
          r_WordCount <= 0;
          r_BitCount <= 0;
          r_read_done <= '0';

        when s_Addr  =>
        when s_PhaseShift =>

        when  s_Data =>
          -- read a bit
          if r_WordCount = 0 then
            o_vendorid(7-r_BitCount) <= i_spi_miso;
          elsif r_WordCount = 1 then
            o_devicetype(7-r_BitCount) <= i_spi_miso;
          else
            o_deviceid(7-r_BitCount) <= i_spi_miso;
          end if;
          r_BitCount <= (r_BitCount + 1) mod 8;
          if r_BitCount = 7 then
            r_WordCount <= (r_WordCount + 1) mod 256;
            if r_WordCount = 2 then
              r_read_done <= '1';
            end if;
          end if;
      end case;
    end if;    
  end process;
  

  -- main write process
  p_write : process (i_clk) is
  begin
    if falling_edge(i_clk) then
      case r_State is
        when s_Idle =>
          o_spi_ce <= '1';
          r_addr_ready <= '0';
          if i_command_ready = '1' then
            r_State <= s_Addr;
            r_Count <= 0;
          end if;
        when s_Addr =>
          o_spi_ce <= '0';
          r_addr_ready <= '0';
          o_spi_mosi <= CMD_JEDEC_ID(7-r_Count);
          r_Count <= (r_Count + 1) mod 8;
          if r_Count = 7 then
            -- TODO: only do a phase shifting clock cycle
            -- if the command is a read command
            r_State <= s_PhaseShift;
          end if;
        when s_PhaseShift =>
          r_State <= s_Data;
          -- not necessary or forbidden, but nice for debugging:
          o_spi_mosi <= '0';
        when s_Data =>
          r_addr_ready <= '1';

          if r_read_done = '1' then
            r_State <= s_Idle;
            o_spi_ce <= '1';
          end if;
      end case;
    end if;

  end process;

  o_done <= '1' when r_State=s_Idle else '0';

end behave;

