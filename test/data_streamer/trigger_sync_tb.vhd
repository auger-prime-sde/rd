library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity trigger_sync_tb is
end trigger_sync_tb;

architecture behave of trigger_sync_tb is
  constant clk_period : time := 10 ns;

  signal stop : std_logic := '0';
  
  signal clk : std_logic;
  signal i_trigger : std_logic;
  signal o_trigger : std_logic;

  component trigger_sync is
    port (
      i_clk  : in std_logic;
      i_trigger : in std_logic;
      o_trigger : out std_logic
      );
  end component;

begin

  dut : trigger_sync
    port map (
      i_clk  => clk,
      i_trigger => i_trigger,
      o_trigger => o_trigger
      );
  
  p_clk : process is
  begin
    if stop = '1' then
      wait;
    end if;

    clk <= '0';
    wait for clk_period/2;
    clk <= '1';
    wait for clk_period/2;
  end process;

  p_test : process is
  begin
    i_trigger <= '0';
    
    wait for 142 ns;
    assert o_trigger = '0' report "false output trigger";
    i_trigger <= '1';
    wait until clk = '1';
    wait until clk = '0';
    wait until clk = '1';
    wait for 1 ns;
    assert o_trigger = '1' report "trigger not detected";
    wait until clk = '0';
    wait until clk = '1';
    wait for 1 ns;
    assert o_trigger = '0' report "trigger not shortened";
    wait for 50 ns;
    assert o_trigger = '0' report "output trigger went high again";
    i_trigger <= '0';

    wait for 152 ns;
    i_trigger <= '1';
    wait for 10 ns;
    i_trigger <= '0';
    wait until clk = '0';
    wait until clk = '1';
    wait for 1 ns;
    assert o_trigger = '1' report "trigger not detected";
    wait until clk = '0';
    wait until clk = '1';
    wait for 1 ns;
    assert o_trigger = '0' report "trigger not deactivated";
    

    wait for 142 ns;
    i_trigger <= '1';
    wait for 8 ns;
    i_trigger <= '0';
    wait for 10 ns;
    i_trigger <= '1';
    wait for 10 ns;
    i_trigger <= '0';
    assert o_trigger = '0' report "output did not return to low";
    wait until clk = '0';
    wait until clk = '1';
    wait for 1 ns;
    assert o_trigger = '1' report "immediate retrigger failed";


    wait for 100 ns;
    stop <= '1';
    wait;
  end process;
end behave;

    
