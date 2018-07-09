library ieee;
use ieee.std_logic_1164.all;

entity settable_counter_tb is
end settable_counter_tb;

architecture behavior of settable_counter_tb is
  constant width: natural := 12;
  constant clk_period : time := 10 ns;

  signal en, clk, set, stop : std_logic := '0';
  signal in_data, out_data : std_logic_vector(width-1 downto 0) := (others => '0');

  component settable_counter is
    generic (g_SIZE : natural);
    port (i_en, i_clk, i_set : in std_logic; i_data : in std_logic_vector(g_SIZE-1 downto 0); o_data : out std_logic_vector(g_SIZE-1 downto 0));
  end component;

begin
  -- DUT instantiation
  dut : settable_counter
    generic map (g_SIZE => width)
    port map (
      i_en => en,
      i_set => set,
      i_clk => clk,
      i_data => in_data,
      o_data => out_data);

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
    wait for 20 ns;
    assert out_data = x"fff" report "Counter incremented while not enabled" severity error;

    en <= '1';
    wait for 40 ns;
    assert out_data = x"003" report "Counter not counting correctly" severity error;

    in_data <= x"009";
    set <= '1';
    wait for 20 ns;
    assert out_data = x"009" report "Failed to load value" severity error;

    en <= '1';
    set <= '0';
    wait for 100 ns;
    assert out_data = x"013" report "Counting continuation error" severity error;

    assert false report "Test passed" severity note;
    stop <= '1';
    wait;
  end process;

end behavior;
