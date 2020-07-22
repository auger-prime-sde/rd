library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_capture_tb is
end spi_capture_tb;

architecture behave of spi_capture_tb is
  constant data_clk_period : time := 8 ns; -- 125 MHz
  constant hk_clk_period   : time := 10 ns; -- 100 MHz
  constant spi_clk_period  : time := 101 ns; -- 10 MHz

  constant write_enable  : std_logic_vector(7 downto 0) := "00000001";
  constant write_disable : std_logic_vector(7 downto 0) := "00000000";
  
  signal spi_clk, data_clk, hk_clk: std_logic := '1';
  signal data : std_logic_vector(3 downto 0) := "1100";
  signal dev  : std_logic_vector(7 downto 0) := (others => '0');
  signal miso, mosi : std_logic;
  
  signal stop : std_logic := '0';

  component spi_capture is
    generic (g_SUBSYSTEM_ADDR : std_logic_vector;
             g_ADC_BITS: natural;
             g_BUFFER_ADDR_BITS : natural := 10 ); -- actually 2048 samples because 2
                                               -- arrive at once every clk
    port ( i_hk_clk : in std_logic;
           i_spi_clk : in std_logic;
           i_spi_mosi : in std_logic;
           o_spi_miso : out std_logic;
           i_dev_select : in std_logic_vector(g_SUBSYSTEM_ADDR'length-1 downto 0);
           -- raw data
           i_data_ns_even : in std_logic_vector(g_ADC_BITS-1 downto 0);
           i_data_ew_even : in std_logic_vector(g_ADC_BITS-1 downto 0);
           i_data_ns_odd  : in std_logic_vector(g_ADC_BITS-1 downto 0);
           i_data_ew_odd  : in std_logic_vector(g_ADC_BITS-1 downto 0);
           i_data_extra   : in std_logic_vector(3 downto 0);
           i_data_clk : in std_logic);
  end component;

begin

  dut : spi_capture
    generic map (
      g_SUBSYSTEM_ADDR   => "00001011",
      g_ADC_BITS         => 4,
      g_BUFFER_ADDR_BITS => 4)
    port map (
      i_hk_clk         => hk_clk,
      i_spi_clk        => spi_clk,
      i_spi_mosi       => mosi,
      o_spi_miso       => miso,
      i_dev_select     => dev,
      i_data_ns_even   => data,
      i_data_ew_even   => data,
      i_data_ns_odd    => data,
      i_data_ew_odd    => data,
      i_data_extra     => (others => '0'),
      i_data_clk       => data_clk);

  p_data: process is
  begin
    if stop = '1' then
      wait;
    else
      data_clk <= '0';
      data <= std_logic_vector(to_unsigned((to_integer(unsigned(data))+1) mod 13, 4));
      wait for data_clk_period/2;
      data_clk <= '1';
      wait for data_clk_period/2;
    end if;
  end process;

  p_hk_clk : process is
  begin
    if stop = '1' then
      wait;
    else
      hk_clk <= not hk_clk;
      wait for hk_clk_period / 2;
    end if;
  end process;
  
    
    


  p_spi: process is
  begin
    spi_clk <= '1';
    wait for 400 ns;

    dev <= "00001011";
    wait for 200 ns;
    for i in 7 downto 0 loop
      wait for spi_clk_period/2;
      spi_clk <= '0';
      mosi <= WRITE_ENABLE(i);
      wait for spi_clk_period/2;
      spi_clk <= '1';
    end loop;
    wait for 200 ns;
    dev <= (others => '0');
    
    wait for 1150 ns;
    
    dev <= "00001011";
    wait for 200 ns;
    for i in 7 downto 0 loop
      wait for spi_clk_period/2;
      spi_clk <= '0';
      mosi <= WRITE_DISABLE(i);
      wait for spi_clk_period/2;
      spi_clk <= '1';
    end loop;
    wait for 200 ns;
    dev <= (others => '0');

    wait for 1 us;
    
    dev <= "00001011";
    wait for 200 ns;
    for i in 1 to 5 * 4 * 2 loop
      wait for spi_clk_period/2;
      spi_clk <= '0';
      wait for spi_clk_period/2;
      spi_clk <= '1';
    end loop;
    wait for 20 ns;
    dev <= (others => '0');

    wait for 1 us;
    
    dev <= "00001011";
    wait for 200 ns;
    for i in 1 to 5 * 4 * 2 loop
      wait for spi_clk_period/2;
      spi_clk <= '0';
      wait for spi_clk_period/2;
      spi_clk <= '1';
    end loop;
    wait for 20 ns;
    dev <= (others => '0');

    wait for 200 ns;

    stop <= '1';
    wait;
  end process;
end behave;
    
  
