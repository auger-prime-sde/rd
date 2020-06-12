library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity triangle_source is
  generic (g_ADC_BITS : natural := 12);
  port (
    i_clk  : in std_logic;
    o_data_even : out std_logic_vector(g_ADC_BITS-1 downto 0) := (others => '0');
    o_data_odd  : out std_logic_vector(g_ADC_BITS-1 downto 0) := (others => '0')
    );
end triangle_source;

architecture behave of triangle_source is
  signal r_count : integer range -2**(g_ADC_BITS-2) to 2**(g_ADC_BITS-2)-1 := 0;
  signal r_rising : std_logic := '1';
begin

  
  process(i_clk) is
  begin
    if rising_edge(i_clk) then
      -- generate triangle
      if r_rising = '1' then
        if r_count = 2**(g_ADC_BITS-2) - 2 then
          r_rising <= '0';
        end if;
        r_count <= r_count + 1;
        o_data_even <= std_logic_vector(to_signed(2 * r_count, g_ADC_BITS));
        o_data_odd  <= std_logic_vector(to_signed(2 * r_count + 1, g_ADC_BITS));
      else
        if r_count = -2**(g_ADC_BITS-2) + 1 then
          r_rising <= '1';
        end if;
        r_count <= r_count - 1;
        o_data_even <= std_logic_vector(to_signed(2 * r_count, g_ADC_BITS));
        o_data_odd  <= std_logic_vector(to_signed(2 * r_count - 1, g_ADC_BITS));
      end if;
    end if;
  end process;
end behave;


