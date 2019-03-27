library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


-- TODO: on clock edge while ce=1 also reset the demuxer for good measure

entity spi_demux is
  generic (
    -- how many device select bits to 'cut' from the start of each transaction
    g_DEV_SELECT_BITS : natural := 8
    );
  port (
    -- SPI interface to UUB:
    i_spi_clk  : in  std_logic;
    i_spi_mosi : in  std_logic;
    --o_spi_miso : out std_logic;
    i_spi_ce   : in  std_logic;
    -- muxer target output:
    o_dev_select   : out std_logic_vector(g_DEV_SELECT_BITS-1 downto 0) := (others => '0')
    );
end spi_demux;

architecture behave of spi_demux is

  signal r_count   : natural range 0 to g_DEV_SELECT_BITS-1 := 0;
  signal r_device  : std_logic_vector(g_DEV_SELECT_BITS-1 downto 0);
  signal r_count_test : std_logic_vector(g_DEV_SELECT_BITS-1 downto 0);
  signal r_dev_out : std_logic_vector(g_DEV_SELECT_BITS-1 downto 0) := (others => '0');

  -- the following flag toggles between transactions
    -- (we could not use a boolean because we'de have no way to clear it from
    -- the main process)
    signal r_reset_flag : std_logic := '0';
  
  -- and the main process remembers the flag state to detect toggles
  signal r_flag_state : std_logic := not r_reset_flag;
  
begin

  -- output the addr of the selected device when active:
  --o_dev_select <= (others => '0') when (r_flag_state /= r_reset_flag) or (r_count /= g_DEV_SELECT_BITS-1) else r_device;
  o_dev_select <= (others => '0') when r_flag_state /= r_reset_flag else r_dev_out;
  
  r_count_test <= std_logic_vector(to_unsigned(r_count, g_DEV_SELECT_BITS));

  p_reset : process(i_spi_ce) is
  begin
    if rising_edge(i_spi_ce) then
      r_reset_flag <= not r_reset_flag;
    end if;
  end process;

  p_main : process(i_spi_clk) is
  begin
    
    if rising_edge(i_spi_clk) and i_spi_ce = '0' then
      -- detect transaction boundary:
      if r_flag_state /= r_reset_flag then
        -- latch first bit:
        r_device(g_DEV_SELECT_BITS-1) <= i_spi_mosi;
        r_count <= 0;
        r_dev_out <= (others => '0');
      else
        if r_count < g_DEV_SELECT_BITS - 1  then
          -- latch further dev bits:
          r_device(g_DEV_SELECT_BITS-r_count-2) <= i_spi_mosi;
          r_count <= r_count + 1;

          
          if r_count = g_DEV_SELECT_BITS - 2 then
            r_dev_out <= r_device;
            r_dev_out(g_DEV_SELECT_BITS-r_count-2) <= i_spi_mosi;
          end if;
          
        else
          
        -- forward
        end if;
      end if;
      r_flag_state <= r_reset_flag;
    end if; -- rising_edge(i_spi_clk)
  end process;
  

end behave;

    
    
    
    
