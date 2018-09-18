--- Simple clock_divider test

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clock_divider is
  port (
    i_clk: in std_logic;
    o_q: out std_logic);
end clock_divider;

architecture behavior of clock_divider is
  -- 40MHz clock / 8 = 5MHz
  constant MAX_COUNT : integer := 8;
  signal r_count : natural range 0 to MAX_COUNT-1 := 0;

begin
  process(i_clk, r_count)
  begin
    if rising_edge(i_clk) then
      if r_count > MAX_COUNT-1 then
        r_count <= 0;
      else
        r_count <= (r_count+1);
      end if;
    end if;
  end process;

  o_q <= '0' when r_count < MAX_COUNT/2 else '1';
end;
