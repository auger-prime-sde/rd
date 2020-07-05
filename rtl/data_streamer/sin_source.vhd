library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity sin_source is
  generic (
    g_ADC_BITS  : natural := 12;
    g_FREQ_SIG  : real := 55.0e6;
    g_FREQ_SAMP : real := 250.0e6;
    g_AMPLITUDE : real := 0.2
    );
  port (
    i_clk  : in std_logic;
    o_data_even : out std_logic_vector(g_ADC_BITS-1 downto 0) := std_logic_vector(to_signed(600, g_ADC_BITS));
    o_data_odd  : out std_logic_vector(g_ADC_BITS-1 downto 0) := (others => '0')
    );
end sin_source;

architecture behave of sin_source is
  signal count : real := 0.0;
begin
  process(i_clk) is
  begin
    if rising_edge(i_clk) then
      count <= count + 2.0;
      o_data_even <= std_logic_vector(to_signed(integer(
        2.0 ** (g_ADC_BITS-2) * g_AMPLITUDE * sin(2.0 * MATH_PI * g_FREQ_SIG / g_FREQ_SAMP * count)), g_ADC_BITS
        ));
      o_data_odd <= std_logic_vector(to_signed(integer(
        2.0 ** (g_ADC_BITS-2) * g_AMPLITUDE * sin(2.0 * MATH_PI * g_FREQ_SIG / g_FREQ_SAMP * (count + 1.0))), g_ADC_BITS
        ));
    end if;
  end process;
end behave;


