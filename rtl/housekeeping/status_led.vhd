library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity status_led is
  generic (
    g_MIN_CURRENT : natural := 750;
    g_MAX_CURRENT : natural := 850;
    g_MIN_VOLTAGE : natural := 550;
    g_MAX_VOLTAGE : natural := 650
   );
  port (
    i_clk : in std_logic;
    i_data : in std_logic_vector(31 downto 0);
    o_led : out std_logic
    );
end status_led;

architecture behave of status_led is
  constant c_SLOW_PERIOD : natural := 100000000;
  constant c_FAST_PERIOD : natural :=  20000000;
  
  signal r_current, r_voltage : natural range 0 to 2**12-1;
  signal test_voltage : std_logic_vector(11 downto 0);
  
  signal r_good, r_slow_blink, r_fast_blink : std_logic;

  component clock_divider is
    generic (
      g_MAX_COUNT: natural);
    port (
      i_clk: std_logic;
      o_clk: std_logic);
  end component;
      
begin
  r_voltage <= to_integer(unsigned(i_data(23 downto 16) & i_data(31 downto 28)));
  r_current <= to_integer(unsigned(i_data( 7 downto  0) & i_data(15 downto 12)));

  --test_voltage <= std_logic_vector(to_unsigned(r_voltage, 12));
  
  r_good <= '0';

  slow_pulse : clock_divider
    generic map ( g_MAX_COUNT => c_SLOW_PERIOD)
    port map (
      i_clk => i_clk,
      o_clk => r_slow_blink
      );
  fast_pulse : clock_divider
    generic map ( g_MAX_COUNT => c_FAST_PERIOD)
    port map (
      i_clk => i_clk,
      o_clk => r_fast_blink
      );

  -- blink slow when no antenna attached (i.e. voltage too high)
  -- blink fast when shorted (i.e. voltage too low)
  -- don't blink during normal operation
  o_led <= r_slow_blink when r_voltage > g_MAX_VOLTAGE else r_fast_blink when r_voltage < g_MIN_VOLTAGE else r_good;
end behave;
