library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity data_streamer_tb is
end data_streamer_tb;

architecture behave of data_streamer_tb is
  -- clock periods
  constant clk_period : time := 8 ns; -- 125 MHz
  --constant tx_clk_period : time := 16.66666 ns; -- 60 MHz
  constant tx_clk_period : time := 17 ns; -- 60 MHz

  -- things that are generics in the real instance
  constant g_ADC_BITS : integer := 12;
  constant g_BUFFER_INDEXSIZE : integer := 11;

  -- clocks and stop signal
  signal  clk, tx_clk, acc_clk, stop : std_logic := '0';

  -- data streams
  signal w_triangle_even,
    w_triangle_odd,
    w_data_ns_even_accumulated,
    w_data_ns_odd_accumulated,
    w_data_ew_even_accumulated,
    w_data_ew_odd_accumulated : std_logic_vector(g_ADC_BITS-1 downto 0);

  signal trigger, trigger_even : std_logic := '0';

  component data_streamer
    generic (
    -- Number of data bits from the ADC channels
    g_ADC_BITS : natural := 12;
    -- Number of bits in index counters (11 gives 2048 samples stored)
    g_BUFFER_INDEXSIZE : natural := 11 );

    port (
      i_adc_data       : in std_logic_vector(4*(g_ADC_BITS)-1 downto 0);
      i_clk            : in std_logic;
      i_tx_clk         : in std_logic;
      i_trigger        : in std_logic;
      i_trigger_even   : in std_logic;
      i_start_transfer : in std_logic;
      i_start_offset   : in std_logic_vector(g_BUFFER_INDEXSIZE downto 0);
      o_tx_data        : out std_logic_vector(1 downto 0);
      o_tx_clk         : out std_logic    );
  end component;


  component triangle_source is
    generic (g_ADC_BITS : natural := 12);
    port (
      i_clk : in std_logic;
      o_data_even : out std_logic_vector(g_ADC_BITS-1 downto 0);
      o_data_odd  : out std_logic_vector(g_ADC_BITS-1 downto 0)
      );
  end component;

  component sawtooth_source is
    generic (g_ADC_BITS : natural := 12);
    port (
      i_clk : in std_logic;
      o_data_even : out std_logic_vector(g_ADC_BITS-1 downto 0);
      o_data_odd  : out std_logic_vector(g_ADC_BITS-1 downto 0)
      );
  end component;

  
  component accumulator is
    generic (
      g_WIDTH : natural;
      g_LENGTH: natural);
    port (
      i_clk  : in std_logic;
      i_data_even: in std_logic_vector(g_WIDTH-1 downto 0);
      i_data_odd: in std_logic_vector(g_WIDTH-1 downto 0);
      o_clk : out std_logic;
      o_data_even: out std_logic_vector(g_WIDTH-1 downto 0);
      o_data_odd: out std_logic_vector(g_WIDTH-1 downto 0)
      );
  end component;
  


begin
  p_clk : process is
  begin
    if stop = '1' then
      wait;
    end if;
    wait for clk_period/2;
    clk <= not clk;
  end process;

  p_tx_clk : process is
  begin
    if stop = '1' then
      wait;
    end if;
    wait for tx_clk_period/2;
    tx_clk <= not tx_clk;
  end process;

  p_test : process is
  begin

    trigger_even <= '0';

    l1 : for i in 1 to 2000 loop
      wait for clk_period;
      report "initial delay " & integer'image(i);
    end loop;
    
    -- pulse trigger
    report "TRIGGER";
    trigger <= '1';
    wait for 10 * clk_period;
    trigger <= '0';
    
    -- wait for result
    l2 : for i in 1 to 2048 loop
      wait for clk_period;
      report "continued capture " & integer'image(i);
    end loop;
    l3 : for i in 1 to 2048 loop
      wait for 13 * tx_clk_period;
      report "transfer " & integer'image(i);
    end loop;
    

    -- next trigger
--    l4 : for i in 1 to 2000 loop
--      wait for clk_period;
--      report "initial delay for second trigger " & integer'image(i);
--    end loop;
--    -- pulse trigger
--    trigger <= '1';
--    trigger_even <= '0';
--    wait for 10 * clk_period;
--    trigger <= '0';
--    -- wait for result
--    l5 : for i in 1 to 2048 loop
--      wait for clk_period;
--      report "continued capture second trigger " & integer'image(i);
--    end loop;
--    l6 : for i in 1 to 2048 loop
--      wait for 13 * tx_clk_period;
--      report "transfer second trigger " & integer'image(i);
--    end loop;
    
    stop <= '1';
    wait;
  end process;
  
    
  

  source : sawtooth_source
    port map (
      i_clk   => clk,
      o_data_even => w_triangle_even,
      o_data_odd  => w_triangle_odd
      );


  accumulator_ns : accumulator
    generic map ( g_WIDTH => g_ADC_BITS,
                  g_LENGTH => 4)
    port map (
      i_clk => clk,
      i_data_even => w_triangle_even,
      i_data_odd  => w_triangle_odd,
      o_clk => acc_clk,
      o_data_even => w_data_ns_even_accumulated,
      o_data_odd  => w_data_ns_odd_accumulated);

  accumulator_ew : accumulator
    generic map ( g_WIDTH => g_ADC_BITS,
                  g_LENGTH => 4)
    port map (
      i_clk => clk,
      i_data_even => w_triangle_even,
      i_data_odd  => w_triangle_odd,
      o_clk => open,
      o_data_even => w_data_ew_even_accumulated,
      o_data_odd  => w_data_ew_odd_accumulated);
  
  

   data_streamer_1 : data_streamer
    generic map (g_BUFFER_INDEXSIZE => g_BUFFER_INDEXSIZE, g_ADC_BITS => g_ADC_BITS)
    port map (
      -- uncomment this to use the accumulated data for a longer window
      -- also use w_accumulator_clk instead of w_ddr_clk below
      --i_adc_data(47 downto 36) => w_data_ew_even_accumulated,
      --i_adc_data(35 downto 24) => w_data_ns_even_accumulated,
      --i_adc_data(23 downto 12) => w_data_ew_odd_accumulated,
      --i_adc_data(11 downto  0) => w_data_ns_odd_accumulated,
      
      -- uncomment these instead if you want perfect triangle waves
      i_adc_data(47 downto 36) => w_triangle_even,
      i_adc_data(35 downto 24) => w_triangle_even,
      i_adc_data(23 downto 12) => w_triangle_odd,
      i_adc_data(11 downto  0) => w_triangle_odd,

      -- or zeroes:
      --i_adc_data(47 downto 36) => (others => '0'),
      --i_adc_data(35 downto 24) => (others => '0'),
      --i_adc_data(23 downto 12) => (others => '0'),
      --i_adc_data(11 downto  0) => (others => '0'),
      -- 
      i_clk            => clk,
      --i_clk            => acc_clk,
      i_tx_clk         => tx_clk,
      i_trigger        => trigger,
      i_trigger_even   => trigger_even,
      i_start_transfer => '1',
      i_start_offset   => std_logic_vector(to_unsigned(1024, g_BUFFER_INDEXSIZE+1)),
      o_tx_data        => open,
      o_tx_clk         => open );

  end;

