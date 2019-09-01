library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity i2c_inttest is 
end i2c_inttest;

architecture behavior of i2c_inttest is

  constant clk_period : time := 20 ns;
  signal clk, stop : std_logic := '0';

  -- input signal
  signal i_trig : std_logic;

  -- signals between modules
  signal r_valid : std_logic;
  signal r_data : t_i2c_word;
  signal r_next : std_logic;

  -- i2c signals
  signal sda : std_logic;
  signal scl : std_logic;

  -- output signals
  signal o_data : std_logic_vector(7 downto 0);

  
  component read_sequence is
    generic (
      g_SEQ_DATA : t_i2c_data
      );
    port (
      i_clk      : in std_logic;
      i_trig     : in std_logic;
      i_next     : in std_logic;
      o_data     : out t_i2c_word;
      o_valid    : out std_logic
      );
  end component;
  
  component i2c2 is
    generic (
      g_ADDR          : std_logic_vector(6 downto 0)
      );
    port (
      i_clk      : in std_logic;
      i_data     : in t_i2c_word;
      i_valid    : in std_logic;
      o_data  : out std_logic_vector (7 downto 0); 
      o_next  : out std_logic;
      sda	  : inout std_logic := 'Z';
      scl	  : inout std_logic := 'Z'
      );
  end component;

  
begin
  --DUT instantiation
  read_sequence_1 : read_sequence
    generic map (
      g_SEQ_DATA => ((data => "00000001", restart => '0', rw => '0'),-- select config register
                     (data => "10000101", restart => '0', rw => '0'),-- trigger conversion
                     (data => "10000000", restart => '0', rw => '0'),-- keep rest at default
                     (data => "00000000", restart => '1', rw => '0'),-- select conversion register
                     (data => "XXXXXXXX", restart => '1', rw => '1'),
                     (data => "XXXXXXXX", restart => '0', rw => '1'))
      )
    port map (
      i_clk   => clk,
      i_trig  => i_trig,
      i_next  => r_next,
      o_data  => r_data,
      o_valid => r_valid
      );

  i2c2_1 : i2c2
    generic map (
      g_ADDR          => "1001000"
      )
    port map(
      i_clk		    => clk,
      i_data        => r_data,
      i_valid	    => r_valid,
      o_data        => o_data,
      o_next        => r_next,
      sda			=> sda,
      scl			=> scl
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
    
    wait for 200 * clk_period;
    stop <= '1';
    wait;
  end process;
end behavior;
