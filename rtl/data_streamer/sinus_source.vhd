library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity sinus_source is
  generic (
    g_ADC_BITS  : natural := 12;
    -- Period can be set using these two
    -- output freq is B / A * F_{samp}
    -- note that A memory will be used
    -- so try to keep A low and B small for high frequencies
    g_PERIOD_A  : natural := 25;
    g_PERIOD_B  : natural := 3;
    g_AMPLITUDE : real := 0.2
    );
  port (
    i_clk  : in std_logic;
    o_data_even : out std_logic_vector(g_ADC_BITS-1 downto 0) := std_logic_vector(to_signed(0, g_ADC_BITS));
    o_data_odd  : out std_logic_vector(g_ADC_BITS-1 downto 0) := (others => '0')
    );
end sinus_source;

architecture behave of sinus_source is
  
    
  signal count : integer range 0 to g_PERIOD_A - 1;
  type t_lookup is array(0 to g_PERIOD_A) of std_logic_vector(g_ADC_BITS-1 downto 0);

  function gen_lookup
    return t_lookup is
    variable x : real;
    variable s : real;
    variable res : t_lookup;
  begin
    for i in 0 to g_PERIOD_A - 1 loop
      x      := real(i * g_PERIOD_B * 2) * MATH_PI / real(g_PERIOD_A);
      s      := 2.0 ** (g_ADC_BITS-2) * g_AMPLITUDE * sin(x);
      res(i) := std_logic_vector(to_signed(integer(s), g_ADC_BITS));
    end loop;
    return res;
  end function gen_lookup;
  
    
    
  signal lookup : t_lookup := gen_lookup;
  
                         
begin
  process(i_clk) is
  begin
    if rising_edge(i_clk) then
      count <= (count + 2) mod g_PERIOD_A;
      o_data_even <= lookup(count);
      o_data_odd  <= lookup((count + 1) mod g_PERIOD_A);
    end if;
  end process;
end behave;


