library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity housekeeping is
  generic (
    g_DEV_SELECT_BITS : natural := 3;
    g_CMD_BITS : natural := 3;
    g_ADDR_BITS : natural := 24;
    g_DATA_IN_BITS : natural := 8;
    g_DATA_OUT_BITS : natural := 16
    );
  port (
    i_clk            : in std_logic;
    -- signals to/from UUB
    i_spi_clk        : in std_logic;
    i_spi_mosi       : in std_logic;
    o_spi_miso       : out std_logic;
    i_spi_ce         : in std_logic;
    --signals to housekeeping sub-modules
    o_device_select  : out std_logic_vector(g_DEV_SELECT_BITS-1 downto 0);
    o_cmd            : out std_logic_vector(g_CMD_BITS-1 downto 0);
    o_data           : out std_logic_vector(g_DATA_OUT_BITS-1 downto 0);
    i_data           : in std_logic_vector(g_DATA_IN_BITS-1 downto 0)
    );

end housekeeping;


architecture behaviour of housekeeping is
  constant dev_ads1015     : std_logic_vector(g_DEV_SELECT_BITS-1 downto 0) := "001";
  constant dev_ads4229     : std_logic_vector(g_DEV_SELECT_BITS-1 downto 0) := "010";
  constant dev_flash       : std_logic_vector(g_DEV_SELECT_BITS-1 downto 0) := "011";
  constant dev_diagnostics : std_logic_vector(g_DEV_SELECT_BITS-1 downto 0) := "100";
  
      
  -- signals definitions
  constant c_buf_size : natural := g_DEV_SELECT_BITS + g_CMD_BITS + g_ADDR_BITS + g_DATA_IN_BITS;
  signal r_spi_data_buffer : std_logic_vector(c_buf_size-1 downto 0) := (others => '-');
  signal r_count : natural range 0 to c_buf_size - 1 := 0;

  type t_State is (s_Idle, s_Req, s_Repl, s_Done);
  signal r_state : t_state := s_Idle;


  -- two signals for the spi buffer and the main process to communicate
  signal r_input_ready : std_logic := '0'; -- goes high after spi packet received
  signal r_input_latched : std_logic := '0'; -- tells the spi buffer that it's
                                              -- safe to continue
  


begin

  -- input buffer process
  p_buffer_in : process (i_spi_clk) is
  begin
    if rising_edge(i_spi_clk) then
      if i_spi_ce = '0' then
        case r_state is
          when s_Idle =>
            r_count <= 0;
            r_state <= s_Req;
            -- already store the first bit
            r_spi_data_buffer(0) <= i_spi_mosi;

          when s_Req =>
            -- store bits 1 and further
            r_spi_data_buffer(r_count + 1) <= i_spi_mosi;
            r_count <= r_count + 1;
            if (r_count = c_buf_size-2) and (r_spi_data_buffer(g_DEV_SELECT_BITS downto 0) = DEV_FLASH) or
              (r_count = g_DEV_SELECT_BITS+g_CMD_BITS+ 8 +g_DATA_IN_BITS-2) and     (r_spi_data_buffer(g_DEV_SELECT_BITS-1 downto 0) /= DEV_FLASH)  then
              -- -1 extra because we already stored bit 0 when r_count was not yet running
              r_state <= s_repl;
              r_input_ready <= '1';
            end if;
          when s_Repl =>
            if r_input_latched = '1' then
              r_state <= s_Idle;
            end if;
          when s_Done =>
            -- state unused for the moment
          
        end case;
      else
        -- immediate reset
        r_state <= s_idle;
        r_count <= 0;
        r_input_ready <= '0';
      end if;--  i_spi_ce = '0'
    end if; -- rising edge
  end process;
  p_buffer_out : process (i_spi_clk) is
  begin
    if falling_edge(i_spi_clk) then

    end if;
  end process;
  
  
  
  
  -- main process
  p_main : process(i_clk) is
  begin
    if rising_edge(i_clk) then
      if r_input_latched = '0' then
        if r_input_ready = '1' then
          -- latch 
          o_device_select <= r_spi_data_buffer(g_DEV_SELECT_BITS-1 down to 0);
          o_cmd           <= r_spi_data_buffer(g_DEV_SELECT_BITS+g_CMD_BITS-1 downto g_DEV_SELECT_BITS);
          o_addr          <= r_spi_data_buffer(g_DEV_SELECT_BITS+g_CMD_BITS+g_ADDR_BITS-1 downto    g_DEV_SELECT_BITS+g_CMD_BITS);
          o_data          <= r_spi_data_buffer(g_DEV_SELECT_BITS+g_CMD_BITS+g_ADDR_BITS+g_DATA_IN_BITS-1  downto g_DEV_SELECT_BITS+g_CMD_BITS+g_ADDR_BITS);
          -- remember that the current value was already latched
          r_input_latched <= '1';
        end if;
      else
        if r_input_ready = '0' then
          r_input_latched <= '0';
        end if;
      end if;
    end if;
  end process;
  
end behaviour;
  
