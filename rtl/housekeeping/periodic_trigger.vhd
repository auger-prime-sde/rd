--- Simple trigger generator

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity periodic_trigger is
  generic (
    g_PERIOD : natural;
    g_HIGH : natural
    );
  port (
    i_clk: in std_logic;
    o_trig: out std_logic
    );
end periodic_trigger;

architecture behavior of periodic_trigger is
  signal r_count : natural range 0 to g_PERIOD-1 := 0;

begin
  process(i_clk)
  begin
    if rising_edge(i_clk) then
      if r_count = g_PERIOD-1 then
        r_count <= 0;
      else
        r_count <= (r_count+1);
      end if;
	  if r_count < g_HIGH then
		o_trig <= '1';
	  else
		o_trig <= '0';
	  end if;
    end if;
  end process;
end;

