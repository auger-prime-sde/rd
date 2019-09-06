library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common.all;



entity read_sequence_tb is 
end read_sequence_tb;

architecture behavior of read_sequence_tb is

  constant clk_period : time := 20 ns;
  signal clk, stop : std_logic := '0';

  signal i_trig : std_logic := '0';
  signal i_next : std_logic := '0';

  component read_sequence is
    generic (
      g_SEQ_DATA : t_i2c_data
      );
    port (
      i_clk      : in std_logic;
      i_trig     : in std_logic;
      i_next     : in std_logic;
      o_data     : out std_logic_vector(7 downto 0);
      o_rw       : out std_logic;
      o_restart  : out std_logic;
      o_valid    : out std_logic;
      o_addr     : out std_logic_vector(2 downto 0)
      );
  end component;

begin

  dut : read_sequence
    generic map (
      g_SEQ_DATA => ((data => "00000001", restart => '0', rw => '0', addr=> "XXX"),-- select config register
                     (data => "10000101", restart => '0', rw => '0', addr=> "XXX"),-- trigger conversion
                     (data => "10000000", restart => '0', rw => '0', addr=> "XXX"),-- keep rest at default
                     (data => "00000000", restart => '1', rw => '0', addr=> "XXX"),-- select conversion register
                     (data => "XXXXXXXX", restart => '1', rw => '1', addr=> "000"),
                     (data => "XXXXXXXX", restart => '0', rw => '1', addr=> "001"),
                     (data => "00000001", restart => '0', rw => '0', addr=> "XXX"),-- select config register
                     (data => "10000101", restart => '0', rw => '0', addr=> "XXX"),-- trigger conversion
                     (data => "10000000", restart => '0', rw => '0', addr=> "XXX"),-- keep rest at default
                     (data => "00000000", restart => '1', rw => '0', addr=> "XXX"),-- select conversion register
                     (data => "XXXXXXXX", restart => '1', rw => '1', addr=> "010"),
                     (data => "XXXXXXXX", restart => '0', rw => '1', addr=> "011"))
      )
    port map (
      i_clk     => clk,
      i_trig    => i_trig,
      i_next    => i_next,
      o_data    => open,
      o_rw      => open,
      o_restart => open,
      o_valid   => open
      );

  p_clk : process is
  begin
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
    wait for 142 ns;
    i_trig <= '1';
    wait for 2 * clk_period;
    i_trig <= '0';
    for i in 0 to 7 loop
      wait for 10 * clk_period;
      i_next <= '1';
      wait for clk_period;
      i_next <= '0';
    end loop;
    
    
    wait for 100 * clk_period;
    stop <= '1';
    wait;
  end process;
end behavior;

