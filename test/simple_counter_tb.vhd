library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity simple_counter_tb is
end simple_counter_tb;

architecture behavior of simple_counter_tb is
  constant width: natural := 4;
  constant clk_period : time := 10 ns;

  signal clk, stop : std_logic := '0';
  signal q : std_logic_vector(width-1 downto 0) := (others => '0');

  component simple_counter is
    generic (g_SIZE : natural);
    port (i_clk : in std_logic; o_q : out std_logic_vector(g_SIZE-1 downto 0));
  end component;

begin
  -- DUT instantiation
  dut : simple_counter
    generic map (g_SIZE => width)
    port map (
      i_clk => clk,
      o_q => q);

  p_clk : process is
  begin
    -- Finish simulation when stop is asserted
    if stop = '1' then
      wait;
    end if;

    clk <= '0';
    wait for clk_period / 2;
    clk <= '1';
    wait for clk_period / 2;
  end process;

  p_test : process is
  begin
    wait for 50 ns;
    assert unsigned(q) = 5 report "Unexpected count" severity error;

    wait for 130 ns;
    assert unsigned(q) = 3 report "Wraparound problem" severity error;

    stop <= '1';
    wait;
  end process;

end behavior;
