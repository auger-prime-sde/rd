library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- module to capture raw traces over housekeeping
-- spi. Not as fast as science readout but convenient
-- for debugging and testing.

entity spi_capture is
  generic (g_SUBSYSTEM_ADDR : std_logic_vector;
           g_DATA_WIDTH: natural;
           g_BUFFER_LEN : natural := 1024 ); -- actually 2048 samples because 2
                                             -- arrive at once every clk
  port ( i_spi_clk : in std_logic;
         i_spi_mosi : in std_logic;
         o_spi_miso : out std_logic;
         i_dev_select : in std_logic_vector(g_SUBSYSTEM_ADDR'length-1 downto 0);
         -- raw data
         i_data : in std_logic_vector(g_DATA_WIDTH-1 downto 0);
         i_data_clk : in std_logic);
end spi_capture;

architecture behave of spi_capture is
  -- ram
  type ram_type is array (g_BUFFER_LEN-1 downto 0) of std_logic_vector (g_DATA_WIDTH-1 downto 0);
  signal ram : ram_type;
  attribute syn_ramstyle : string;
  attribute syn_ramstyle of ram : signal is "block_ram";
  
  -- signals
  signal r_spi_ce       : std_logic;
  signal r_spi_clk      : std_logic;
  signal r_spi_clk_prev : std_logic;
  signal r_spi_miso   : std_logic := '0';
  signal r_read_bit   : natural range 0 to g_DATA_WIDTH-1;
  signal r_read_data  : std_logic_vector(g_DATA_WIDTH-1 downto 0);
  signal r_addr       : natural range 0 to g_BUFFER_LEN-1;

begin

  -- silence data when not in use
  o_spi_miso <= r_spi_miso when r_spi_ce = '0' else '0';


  -- this process implements a single-port ram.
  -- If we implement this in any other way lattice will use a
  -- pseudo dual-port ram block which is not correct and results in strange
  -- runtime behaviour and very long compile times (even when timing
  -- constraints are met)
  process(i_data_clk) is
  begin
    if rising_edge(i_data_clk) then
      -- bring ce and spi clk into our clock domain
      if i_dev_select = g_SUBSYSTEM_ADDR then
        r_spi_ce <= '0';
      else
        r_spi_ce <= '1';
      end if;
      r_spi_clk     <= i_spi_clk;
      -- latch old values so we can soft-detect rising and falling edges
      r_spi_clk_prev <= r_spi_clk;

      if r_spi_ce = '1' then
        -- write part:
        r_addr <= (r_addr + 1) mod g_BUFFER_LEN;
        ram(r_addr) <= i_data;
        -- reset the read counter
        r_read_bit <= 0;
        r_read_data <= (others => 'X');-- just an optimization
      else -- if r_spi_ce = '0'
        -- read part
        r_read_data <= ram((r_addr) mod g_BUFFER_LEN);
        if r_spi_clk = '0' and r_spi_clk_prev = '1' then
          -- increment bit counter for next cycle
          r_read_bit <= (r_read_bit + 1) mod g_DATA_WIDTH;
          -- write output bit
          --r_spi_miso <= r_read_data(r_read_bit);
          r_spi_miso <= r_read_data(g_DATA_WIDTH-r_read_bit-1);
          -- increment addr if bit counter overflows
          if r_read_bit = g_DATA_WIDTH-1 then
            r_addr <= (r_addr + 1) mod g_BUFFER_LEN;
          end if;
        end if;
      end if;
    end if;
  end process;
  
end behave;

