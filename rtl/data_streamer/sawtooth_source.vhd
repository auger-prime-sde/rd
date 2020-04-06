library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sawtooth_source is
  generic (g_ADC_BITS : natural := 12);
  port (
    i_clk  : in std_logic;
    o_data_even : out std_logic_vector(g_ADC_BITS-1 downto 0);
    o_data_odd  : out std_logic_vector(g_ADC_BITS-1 downto 0)
    );
end sawtooth_source;

architecture behave of sawtooth_source is
  signal r_count : integer range -2**(g_ADC_BITS-2) to 2**(g_ADC_BITS-2)-1 := 0;
begin


  p_test: process is
  begin
    wait;
  end process;
  
  
  process(i_clk) is
  begin
    if rising_edge(i_clk) then
      if r_count = 2**(g_ADC_BITS-2)-1 then
        r_count <= -2**(g_ADC_BITS-2);
      else
        r_count <= r_count + 1;
      end if;
      o_data_even <= std_logic_vector(to_signed(2 * r_count, g_ADC_BITS));
      o_data_odd  <= std_logic_vector(to_signed(2 * r_count + 1, g_ADC_BITS));
    end if;
  end process;
end behave;


