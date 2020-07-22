library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- module to capture raw traces over housekeeping
-- spi. Not as fast as science readout but convenient
-- for debugging and testing.

entity spi_capture is
  generic (g_SUBSYSTEM_ADDR : std_logic_vector;
           g_ADC_BITS: natural;
           g_BUFFER_ADDR_BITS : natural := 10 ); -- actually 2048 samples because 2
                                                 -- arrive at once every clk
  port ( i_hk_clk     : in std_logic;
         i_spi_clk    : in std_logic;
         i_spi_mosi   : in std_logic;
         o_spi_miso   : out std_logic;
         i_dev_select : in std_logic_vector(g_SUBSYSTEM_ADDR'length-1 downto 0);
         -- raw data
         i_data_ns_even : in std_logic_vector(g_ADC_BITS-1 downto 0);
         i_data_ew_even : in std_logic_vector(g_ADC_BITS-1 downto 0);
         i_data_ns_odd  : in std_logic_vector(g_ADC_BITS-1 downto 0);
         i_data_ew_odd  : in std_logic_vector(g_ADC_BITS-1 downto 0);
         i_data_extra   : in std_logic_vector(3 downto 0);
         i_data_clk     : in std_logic );
end spi_capture;

architecture behave of spi_capture is
  constant g_DATA_WIDTH : natural := 4 * (g_ADC_BITS + 1);
  constant g_BUFFER_LEN : natural := 2 ** g_BUFFER_ADDR_BITS;
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
  signal r_read_data, r_write_data  : std_logic_vector(g_DATA_WIDTH-1 downto 0);
  --signal r_addr       : natural range 0 to g_BUFFER_LEN-1;
  signal w_write_enable : std_logic;
  signal w_control_register_out : std_logic_vector(7 downto 0);
  signal r_write_enable_prev : std_logic := '0';

  signal r_write_addr    : std_logic_vector(g_BUFFER_ADDR_BITS-1 downto 0);
  signal write_addr      : integer range 0 to g_BUFFER_LEN - 1 := 0;
  signal write_addr_sync : std_logic_vector(g_BUFFER_ADDR_BITS-1 downto 0);
  signal write_addr_sync_prev : std_logic_vector(g_BUFFER_ADDR_BITS-1 downto 0);
  signal read_addr       : integer range 0 to g_BUFFER_LEN - 1 := 0;

  --signal t_read_bit : std_logic_vector(15 downto 0);
  --signal t_addr     : std_logic_vector(15 downto 0);
  
  component spi_register is
    generic (
      g_SUBSYSTEM_ADDR : std_logic_vector;
      g_REGISTER_WIDTH : natural := 8;
      g_DEFAULT : std_logic_vector(g_REGISTER_WIDTH-1 downto 0)
      );
    port (
      i_hk_fast_clk : in std_logic;
      i_spi_clk : in std_logic;
      i_spi_mosi : in std_logic;
      o_spi_miso : out std_logic;
      i_dev_select : in std_logic_vector(g_SUBSYSTEM_ADDR'length-1 downto 0);
      i_set : in  std_logic_vector(g_REGISTER_WIDTH-1 downto 0);
      i_clr : in  std_logic_vector(g_REGISTER_WIDTH-1 downto 0);
      o_data: out std_logic_vector(g_REGISTER_WIDTH-1 downto 0)
      );
  end component;

  component sync_1bit is
    generic (
      g_NUM_STAGES : natural := 3
      );
    port (
      i_clk : in std_logic;
      i_data :in  std_logic;
      o_data : out std_logic
      );
  end component;

  component sync_vector is
    generic (
      g_WIDTH : natural
      );
    port (
      i_clk  : in  std_logic;
      i_data : in  std_logic_vector(g_WIDTH-1 downto 0);
      o_data : out std_logic_vector(g_WIDTH-1 downto 0)
      );
  end component;



begin

  --t_addr     <= std_logic_vector(to_unsigned(r_addr, 16));
  --t_read_bit <= std_logic_vector(to_unsigned(r_read_bit, 16));

  r_write_data <= i_data_extra(3) & i_data_ns_even &
                  i_data_extra(2) & i_data_ew_even &
                  i_data_extra(1) & i_data_ns_odd &
                  i_data_extra(0) & i_data_ew_odd;
  
  
  control_register : spi_register
    generic map (
      g_SUBSYSTEM_ADDR => g_SUBSYSTEM_ADDR, -- shared with data
      g_REGISTER_WIDTH => 8, -- can't set this to 1 because that triggers a bug
      g_DEFAULT => std_logic_vector(to_unsigned(0, 8))) -- start in writing mode
      -- TODO: I changed the above default from 1 to 0, check that it still works
    port map (
      i_hk_fast_clk => i_hk_clk,
      i_spi_clk     => i_spi_clk,
      i_spi_mosi    => i_spi_mosi,
      o_spi_miso    => open,
      i_dev_select  => i_dev_select,
      i_set         => (others => '0'),
      i_clr         => (others => '0'),
      o_data        => w_control_register_out
      );

  write_enable_sync : sync_1bit
    port map (
      i_clk =>  i_data_clk,
      i_data => w_control_register_out(0),
      o_data => w_write_enable
      );


  r_write_addr <= std_logic_vector(to_unsigned(write_addr, g_BUFFER_ADDR_BITS));
  addr_sync : sync_vector
    generic map (
      g_WIDTH => g_BUFFER_ADDR_BITS
      )
    port map (
      i_clk  => i_hk_clk,
      i_data => r_write_addr,
      o_data => write_addr_sync
      );
  

  -- pick first output bit as write enable line
  --w_write_enable <= w_control_register_out(0);

  -- silence data when not in use
  r_spi_ce   <= '0' when i_dev_select = g_SUBSYSTEM_ADDR else '1';
  o_spi_miso <= r_spi_miso when r_spi_ce = '0' else '0';

  

  p_write : process (i_data_clk) is
  begin
    if rising_edge(i_data_clk) then
      if w_write_enable = '1' then
        ram(write_addr) <= r_write_data;
        write_addr <= (write_addr + 1) mod g_BUFFER_LEN;
      end if;
    end if;
  end process;

  p_read : process (i_hk_clk) is
  begin

    r_read_data <= ram(read_addr);
    
    if rising_edge(i_hk_clk) then
      write_addr_sync_prev <= write_addr_sync;
      -- since the sync also waits for two consecutive identical
      -- values, we can use that to detect when the write process has stopped
      if write_addr_sync /= write_addr_sync_prev then
        read_addr <= to_integer(unsigned(write_addr_sync));
      end if;
      

      r_spi_clk     <= i_spi_clk;
      r_spi_clk_prev <= r_spi_clk;
      
      if r_spi_ce = '0' then
        -- output next bit on falling clk
        if r_spi_clk = '0' and r_spi_clk_prev = '1' then
          r_spi_miso <= r_read_data(g_DATA_WIDTH-r_read_bit-1);
          
          -- increment bit counter for next cycle
          r_read_bit <= (r_read_bit + 1) mod g_DATA_WIDTH;
          -- increment addr if bit counter overflows
          if r_read_bit = g_DATA_WIDTH-1 then
            read_addr <= (read_addr + 1) mod g_BUFFER_LEN;
          end if;
        end if;
      else
        -- reset the read counter
        r_read_bit <= 0;
        --read_addr <= to_integer(unsigned(write_addr_sync));
      end if;
    end if;
  end process;
  
end behave;

