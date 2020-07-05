library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

entity sinus_source_tb is
end sinus_source_tb;


architecture behave of sinus_source_tb is
  constant clk_period : time := 8 ns; -- 125 MHz
  signal clk : std_logic;
  
  component sinus_source is
    generic (
      g_ADC_BITS  : natural := 12;
      g_PERIOD_A  : natural := 25;
      g_PERIOD_B  : natural := 3;
      g_AMPLITUDE : real := 0.2    );
    port (
      i_clk : in std_logic;
      o_data_even : out std_logic_vector(g_ADC_BITS-1 downto 0);
      o_data_odd  : out std_logic_vector(g_ADC_BITS-1 downto 0)
      );
  end component;

begin
  dut : sinus_source
    generic map (
      g_ADC_BITS  => 12,
      g_PERIOD_A  => 25,
      g_PERIOD_B  => 1,
      g_AMPLITUDE => 0.2
      )
    port map (
      i_clk  => clk,
      o_data_even => open,
      o_data_odd  => open
      );

  p_clk : process is
  begin
    for i in 0 to 15000 loop
      clk <= '0';
      wait for clk_period / 2;
      clk <= '1';
      wait for clk_period / 2;
    end loop;
    wait;
  end process;
end behave;
