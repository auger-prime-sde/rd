library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clock_divider_tb is
end clock_divider_tb;

architecture behavior of clock_divider_tb is
  constant width: natural := 12;
  constant clk_period : time := 10 ns;

  signal i_clk : std_logic := '0';
  signal o_clk : std_logic := '0';
  signal stop : std_logic := '0';
  signal ratio : std_logic_vector(width-1 downto 0) := std_logic_vector(to_unsigned(5, width));

  component clock_divider is
    generic (g_SIZE : natural);
    port (
      i_clk     : in std_logic;
      o_clk     : out std_logic;
      i_ratio   : in std_logic_vector(g_SIZE-1 downto 0)
    );
  end component;

begin
  -- DUT instantiation
  dut : clock_divider
    generic map (g_SIZE => width)
    port map (
      i_clk => i_clk,
      o_clk => o_clk,
      i_ratio => ratio
    );

  p_clk : process is
  begin
    -- Finish simulation when stop is asserted
    if stop = '1' then
      wait;
    end if;

    wait for clk_period / 2;
    i_clk <= '1';
    wait for clk_period / 2;
    i_clk <= '0';
  end process;

  p_test : process is
  begin
    wait for clk_period * 9.5; -- due to weird behaviour of simultor the first
                             -- clock cycle is 0.5 a clk period short
    for a in 0 to 10 loop
      for i in 0 to 4 loop
        wait for clk_period;
        assert o_clk = '0' report "clock went high too soon";
      end loop;
    
      for i in 0 to 4 loop
        wait for clk_period;
        assert o_clk = '1' report "clock went low too soon";
      end loop;
    end loop;
    
    stop <= '1';
    wait;
  end process;

end behavior;
