library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- calculate the running average
-- The idea is that the register contain N*mean(X1, X2, ...) = (X1 + X2 + ...)
-- when we receive Xn we add Xn to the register. Since we don't remember the
-- exact value of (X_(n-4096)) which we should subtract, we subtract mean()
-- instead which, on average, is correct. The mean is calculated not by
-- division but by bit select. Hence the choice for a power of 2 in averaging
-- window.

entity running_avg is
  generic (
    g_ADC_BITS : natural := 12;
    g_AVG_NUM_BITS : natural := 12 -- for 4096 sample averaged output 
    );
  port (
    i_clk : std_logic;
    i_data_even : in std_logic_vector(g_ADC_BITS-1 downto 0);
    i_data_odd  : in std_logic_vector(g_ADC_BITS-1 downto 0);
    --o_avg       : out std_logic_vector(g_ADC_BITS-1 downto 0)
    o_avg       : out integer range -(2 ** (g_ADC_BITS - 1)) to 2 ** (g_ADC_BITS - 1) - 1 := 0
-- default somehow needed for ghdl
    );
end running_avg;


architecture behave of running_avg is
  -- number of bits needed for internal numbers without rounding or wrapping
  constant TOTAL_BITS : natural := g_AVG_NUM_BITS + g_ADC_BITS;


  -- using an integer enforces ranges during simulation
  signal r_total : integer range -(2 ** (TOTAL_BITS - 1)) to 2 ** (TOTAL_BITS - 1) - 1 := 0;
  signal w_average : integer range -(2 ** (g_ADC_BITS - 1)) to 2 ** (g_ADC_BITS - 1) - 1 :=
    0;--default only for ghdl


begin
  
  -- since we average over a power of 2 the average is simply the total with
  -- g_AVG_NUM_BITS discarded from the lower end.
  w_average <= to_integer(to_signed(r_total, TOTAL_BITS)(TOTAL_BITS-1 downto g_AVG_NUM_BITS));

  -- on every clk we add the new inputs and subtract twice the current mean
  p_avg : process (i_clk) is
  begin
    if rising_edge(i_clk) then
      r_total <= r_total - (2 * w_average) + (to_integer(signed(i_data_odd)) + to_integer(signed(i_data_even)));
    end if;
  end process;

  -- we output the current mean
  o_avg <= w_average;
end behave;

  
