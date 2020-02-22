library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity accumulator_tb is
end accumulator_tb;


architecture behave of accumulator_tb is
  constant clk_period : time := 10 ns;
  
  signal clk : std_logic;
  signal stop : std_logic := '0';


  signal data_even, data_odd : std_logic_vector(11 downto 0);
  
  
  component accumulator is
    generic (g_WIDTH : natural;
             g_LENGTH: natural);
    port (i_clk : in std_logic;
          i_data_even: in std_logic_vector(g_WIDTH-1 downto 0);
          i_data_odd: in std_logic_vector(g_WIDTH-1 downto 0);
          o_clk : out std_logic;
          o_data_even: out std_logic_vector(g_WIDTH-1 downto 0);
          o_data_odd: out std_logic_vector(g_WIDTH-1 downto 0)
          );
  end component;

  component triangle_source is
    generic (g_ADC_BITS : natural := 12);
    port (
      i_clk : in std_logic;
      o_data_even : out std_logic_vector(g_ADC_BITS-1 downto 0);
      o_data_odd : out std_logic_vector(g_ADC_BITS-1 downto 0)
      );
  end component;

  
begin

  source : triangle_source
    generic map ( g_ADC_BITS => 12)
    port map (
      i_clk  => clk,
      o_data_even => data_even,
      o_data_odd  => data_odd
      );

  dut : accumulator
    generic map (
      g_WIDTH => 12,
      g_LENGTH => 4)
    port map (
      i_clk => clk,
      i_data_even => data_even,
      i_data_odd => data_odd,
      o_clk => open,
      o_data_even => open,
      o_data_odd  => open);

  
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
    wait for 8 us;
    stop <= '1';
    wait;
  end process;
  
    
  


  
end architecture behave;

