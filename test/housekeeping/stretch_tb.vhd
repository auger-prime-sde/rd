library ieee;
use ieee.std_logic_1164.all;

entity stretch_tb is
end stretch_tb;


architecture behave of stretch_tb is
  constant clk_period : time := 10 ns;
  
  signal clk, stop, i_data, o_data : std_logic := '0';

  component stretch is
    generic (
      g_LENGTH : natural := 3
      );
    port (
      i_clk  : in std_logic;
      i_data : in std_logic;
      o_data : out std_logic
      );
  end component;

begin

  dut : stretch
    generic map (
      g_LENGTH => 10
      )
    port map (
      i_clk => clk,
      i_data => i_data,
      o_data => o_data
      );

  p_clk : process is
  begin
    if stop = '1' then
      wait;
    else
      clk <= not clk;
      wait for clk_period / 2;
    end if;
  end process;

  p_test : process is
  begin
    wait for 100 ns;
    assert o_data = '0' report "output high before input risen";
    i_data <= '1';
    for i in 1 to 10 loop
      wait for clk_period;
      i_data <= '0';
      assert o_data = '1' report "output not stretched long enough";
    end loop;
    wait for clk_period;
    assert o_data = '0' report "output stretched too long";

    wait for 100 ns;
    
    i_data <= '1';
    wait for 2 * clk_period;
    i_data <= '0';
    wait for 5 * clk_period;
    i_data <= '1';
    wait for 2 * clk_period;
    i_data <= '0';

    wait for 100 * clk_period;

    i_data <= '1';
    wait for 2 * clk_period;
    i_data <= '0';
    wait for 5 * clk_period;
    i_data <= '1';
    wait for 20 * clk_period;
    i_data <= '0';

    wait for 10 * clk_period;

    stop <= '1';
    wait;
    
  end process;
  
  
end behave;
