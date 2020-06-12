library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

entity test_source_tb is
end test_source_tb;


architecture behave of test_source_tb is
  constant clk_period : time := 10 ns;
  signal clk : std_logic;
  signal stop : std_logic := '0';
  signal peak_count : integer := 0;
  signal peak_detected : std_logic := '0';
  signal data_even, data_odd : std_logic_vector(11 downto 0);
  
  component test_source is
    generic (g_ADC_BITS : natural := 12);
    port (
      i_clk : in std_logic;
      o_data_even : out std_logic_vector(g_ADC_BITS-1 downto 0);
      o_data_odd  : out std_logic_vector(g_ADC_BITS-1 downto 0)
      );
  end component;

begin
  dut : test_source
    generic map ( g_ADC_BITS => 12)
    port map (
      i_clk  => clk,
      o_data_even => data_even,
      o_data_odd  => data_odd
      );

  p_clk : process is
  begin
    if stop = '1' then
      wait;
    else
      clk <= '0';
      wait for clk_period / 2;
      clk <= '1';
      wait for clk_period / 2;
    end if;
  end process;


  peak_detected <= '1' when
    to_integer(signed(data_even)) >  150 or
    to_integer(signed(data_even)) < -150 or
    to_integer(signed(data_odd )) >  150 or
    to_integer(signed(data_odd )) < -150
    else '0';

  p_main : process is
  begin
    wait until clk = '1';
    if peak_detected = '1' then
      peak_count <= peak_count + 1;
      if peak_count = 15 then
        stop <= '1';
        wait;
      end if;
    end if;
  end process;
  
end behave;

    
