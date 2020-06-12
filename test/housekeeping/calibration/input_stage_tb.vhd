library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity input_stage_tb is
end input_stage_tb;

architecture behave of input_stage_tb is


  component input_stage is
    generic (
      g_ADC_BITS : natural := 12;
      LOG2_FFT_LEN : integer := 11;
      QUIET_THRESHOLD : integer := 50
      );
    port (
      i_data_clk : in std_logic;
      i_hk_clk   : in std_logic;
      i_data_ns_even : in std_logic_vector(g_ADC_BITS-1 downto 0);
      i_data_ns_odd  : in std_logic_vector(g_ADC_BITS-1 downto 0);
      i_data_ew_even : in std_logic_vector(g_ADC_BITS-1 downto 0);
      i_data_ew_odd  : in std_logic_vector(g_ADC_BITS-1 downto 0);
      o_valid   : out std_logic;
      o_addr    : out std_logic_vector(LOG2_FFT_LEN-1 downto 0);
      o_start   : out std_logic;
      o_data_even : out std_logic_vector(g_ADC_BITS-1 downto 0);
      o_data_odd : out std_logic_vector(g_ADC_BITS-1 downto 0);
      i_rearm   : in std_logic
      );
  end component;

  component triangle_source is
    generic (g_ADC_BITS : natural := 12);
    port (
      i_clk  : in std_logic;
      o_data_even : out std_logic_vector(g_ADC_BITS-1 downto 0);
      o_data_odd  : out std_logic_vector(g_ADC_BITS-1 downto 0)
      );
  end component;
  component test_source is
    generic (g_ADC_BITS : natural := 12);
    port (
      i_clk  : in std_logic;
      o_data_even : out std_logic_vector(g_ADC_BITS-1 downto 0);
      o_data_odd  : out std_logic_vector(g_ADC_BITS-1 downto 0)
      );
  end component;

  constant period_data : time := 8 ns;  -- 125 MHz
  constant period_hk   : time := 10 ns; -- 100 MHz
  
  signal data_clk : std_logic := '0';
  signal hk_clk : std_logic := '0';
  signal stop : std_logic := '0';

  signal triangle_even, triangle_odd : std_logic_vector(11 downto 0) := (others => '0');
  signal rearm : std_logic := '0';

  
begin

  p_data_clk : process is
  begin
    if stop = '1' then
      wait;
    end if;
    wait for period_data / 2;
    data_clk <= not data_clk;
  end process;

  p_hk_clk : process is
  begin
    if stop = '1' then
      wait;
    end if;
    wait for period_hk / 2;
    hk_clk <= not hk_clk;
  end process;

  p_test : process is
  begin
    wait for 100 * period_data;
    rearm <= '1';
    wait for period_data;
    rearm <= '0';
    wait for 100 * period_data;
    stop <= '1';
    wait;
  end process;
  
  
  source: test_source
    port map (
      i_clk => data_clk,
      o_data_even => triangle_even,
      o_data_odd  => triangle_odd
      );
  
  
  dut: input_stage
    generic map (
      LOG2_FFT_LEN => 5
      )
    port map (
      i_data_clk => data_clk,
      i_hk_clk   => hk_clk,
      i_data_ns_even => triangle_even,
      i_data_ns_odd  => triangle_odd,
      i_data_ew_even => triangle_even,
      i_data_ew_odd  => triangle_odd,
      o_valid   => open,
      o_addr    => open,
      o_start   => open,
      o_data_even => open,
      o_data_odd => open,
      i_rearm   => rearm
      );
      

end behave;



    


    
