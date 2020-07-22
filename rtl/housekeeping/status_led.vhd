library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity status_led is
  generic (
    g_MIN_VOLTAGE : natural;
    g_MAX_VOLTAGE : natural
   );
  port (
    i_clk  : in std_logic;
    i_data : in std_logic_vector(31 downto 0);
    o_led  : out std_logic
    );
end status_led;

architecture behave of status_led is
  constant c_SLOW_PERIOD : natural := 100000000;
  constant c_FAST_PERIOD : natural :=  20000000;
  
  signal r_current : natural range 0 to (2**12)-1;
  signal r_voltage : natural range 0 to (2**12)-1;
  
  signal r_slow_blink: std_logic;
  signal r_fast_blink: std_logic;

  signal r_too_low : std_logic;
  signal r_too_high : std_logic;

  component clock_divider is
    generic (
      g_MAX_COUNT: natural);
    port (
      i_clk: in std_logic;
      o_clk: out std_logic);
  end component;
      
begin
  
--  slow_blinker : clock_divider
--    generic map ( g_MAX_COUNT => c_SLOW_PERIOD)
--    port map (  i_clk => i_clk,
--                o_clk => r_slow_blink  );
  fast_blinker : clock_divider
    generic map ( g_MAX_COUNT => c_FAST_PERIOD)
    port map (  i_clk => i_clk,
                o_clk => r_fast_blink  );
  slow_blinker : clock_divider
    generic map ( g_MAX_COUNT => c_SLOW_PERIOD / c_FAST_PERIOD)
    port map ( i_clk => r_fast_blink,
               o_clk => r_slow_blink );
      
      

  
  
  r_voltage <= to_integer(unsigned(i_data(23 downto 16) & i_data(31 downto 28)));
  r_current <= to_integer(unsigned(i_data( 7 downto  0) & i_data(15 downto 12)));
  
  
  r_too_low  <= '1' when r_voltage <= g_MIN_VOLTAGE else '0';
  r_too_high <= '1' when r_voltage >= g_MAX_VOLTAGE else '0';
  
  -- blink slow when no antenna attached (i.e. voltage too high)
  -- blink fast when shorted (i.e. voltage too low)
  -- don't blink during normal operation
  o_led <= (r_slow_blink and r_too_high) or (r_fast_blink and r_too_low);
  
end behave;
