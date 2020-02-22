library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_capture_tb is
end spi_capture_tb;

architecture behave of spi_capture_tb is
  constant data_clk_period : time := 8 ns; -- 125 MHz
  constant spi_clk_period  : time := 100 ns; -- 10 MHz

  signal spi_clk, data_clk: std_logic;
  signal data : std_logic_vector(11 downto 0) := "110000000000";
  signal dev  : std_logic_vector(7 downto 0) := (others => '0');

  signal stop : std_logic := '0';

  component spi_capture is
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
  end component;

begin

  dut : spi_capture
    generic map (
      g_SUBSYSTEM_ADDR => "00010010",
      g_DATA_WIDTH     => 12,
      g_BUFFER_LEN     => 16)
    port map (
      i_spi_clk        => spi_clk,
      i_spi_mosi       => '0',
      o_spi_miso       => open,
      i_dev_select     => dev,
      i_data           => data,
      i_data_clk       => data_clk);

  p_data: process is
  begin
    if stop = '1' then
      wait;
    else
      data_clk <= '0';
      data <= std_logic_vector(to_unsigned((to_integer(unsigned(data))+1) mod 4096, 12));
      wait for data_clk_period/2;
      data_clk <= '1';
      wait for data_clk_period/2;
    end if;
  end process;


  p_spi: process is
  begin
    spi_clk <= '1';
    wait for 400 ns;
    dev <= "00010010";

    for i in 1 to 12*16 loop
      wait for spi_clk_period/2;
      spi_clk <= '0';
      wait for spi_clk_period/2;
      spi_clk <= '1';
    end loop;
    wait for spi_clk_period/2;
    dev <= (others => '0');

    wait for 200 ns;

    stop <= '1';
    wait;
  end process;
end behave;
    
  
