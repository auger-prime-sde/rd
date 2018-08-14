library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clock_divider is
  generic (
    g_SIZE : natural := 12
  );
  port (
    -- clocks
    i_clk     : in std_logic := '0';
    o_clk     : out std_logic := '0';
    -- config input: this many clock cycles on input will become one 
    -- clock cycle on the output clock
    i_ratio   : in std_logic_vector(g_SIZE-1 downto 0)
    );
end clock_divider;


architecture behave of clock_divider is
  -- variables:
  signal r_counter : std_logic_vector(g_SIZE-1 downto 0) := (others=>'0');
  signal r_clk : std_logic := '0';
begin
  p_counter : process (i_clk) is
  begin
--    if i_clk'event then
      if unsigned(r_counter) < unsigned(i_ratio) - 1 then
        r_counter <= std_logic_vector(unsigned(r_counter) + 1);
        r_clk <= r_clk;
      else
        r_counter <= (others=>'0');
        r_clk <= not r_clk;
      end if;
--    end if;
  end process;
  o_clk <= r_clk;
end behave;
 
