library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clock_divider_tb is
end clock_divider_tb;

architecture behave of clock_divider_tb is
  constant clk_period : time := 8 ns;
  signal i_clk, o_clk, stop : std_logic := '0';

  component clock_divider is
    generic (
    g_MAX_COUNT : natural
    );
  port (
    i_clk: in std_logic;
    o_clk: out std_logic
    );
  end component;

begin

  dut : clock_divider
    generic map (
      g_MAX_COUNT => 2
      )
    port map (
      i_clk => i_clk,
      o_clk => o_clk
      );

  p_clk : process is
  begin
    if stop = '1' then
      wait;
    else
      i_clk <= '0';
      wait for clk_period / 2;
      i_clk <= '1';
      wait for clk_period / 2;
    end if;
  end process;

  p_test : process is
  begin
    wait for 100 * clk_period;
    stop <= '1';
    wait;
  end process;
      
  
end behave;
