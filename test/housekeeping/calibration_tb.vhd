library ieee;
use ieee.std_logic_1164.all;

entity calibration_tb is
end calibration_tb;

architecture behave of calibration_tb is
  ----------------------------------
  -- Constants
  ----------------------------------
  constant clk_period_data : time :=   8 ns; -- 125 MHz
  constant clk_period_fft  : time := 100 ns; --  10 MHz
  constant clk_period_hk   : time :=  10 ns; -- 100 MHz
  constant clk_period_spi  : time := 200 ns; --   5 MHz

  constant control_REQ_BREAK : std_logic_vector := "00000001";
  constant control_REQ_CLEAR : std_logic_vector := "00000011";
  constant control_CONTINUE  : std_logic_vector := "00000000";
  

  ---------------------------------
  -- Sub component declarations
  ---------------------------------
  component calibration is
    generic (
      g_CONTROL_SUBSYSTEM_ADDR : std_logic_vector;
      g_READOUT_SUBSYSTEM_ADDR : std_logic_vector;
      g_ADC_BITS : natural := 12;
      LOG2_FFT_LEN : integer := 10;
      QUIET_THRESHOLD : integer := 50
      );
    port (
      -- clk
      i_data_clk    : in std_logic;
      i_fft_clk     : in std_logic;
      i_hk_fast_clk : in std_logic;
      -- data input:
      i_data_ns_even : in std_logic_vector(g_ADC_BITS-1 downto 0);
      i_data_ns_odd  : in std_logic_vector(g_ADC_BITS-1 downto 0);
      i_data_ew_even : in std_logic_vector(g_ADC_BITS-1 downto 0);
      i_data_ew_odd  : in std_logic_vector(g_ADC_BITS-1 downto 0);
      -- spi interface for readout:
      i_spi_clk     : in std_logic;
      i_dev_select  : in std_logic_vector(g_CONTROL_SUBSYSTEM_ADDR'length-1 downto 0);
      i_spi_mosi    : in std_logic;
      o_spi_miso    : out std_logic
      );
  end component;

  component sin_source is
    generic (
      g_ADC_BITS  : natural := 12;
      g_FREQ_SIG  : real := 55.0e6;
      g_FREQ_SAMP : real := 250.0e6;
      g_AMPLITUDE : real := 0.2    );
    port (
      i_clk : in std_logic;
      o_data_even : out std_logic_vector(g_ADC_BITS-1 downto 0);
      o_data_odd  : out std_logic_vector(g_ADC_BITS-1 downto 0)
      );
  end component;

  component triangle_source is
    generic (g_ADC_BITS : natural := 12);
    port (
      i_clk  : in std_logic;
      o_data_even : out std_logic_vector(g_ADC_BITS-1 downto 0) := (others => '0');
      o_data_odd  : out std_logic_vector(g_ADC_BITS-1 downto 0) := (others => '0')
      );
  end component;

  component sinus_source is
    generic (
      g_ADC_BITS  : natural := 12;
      g_PERIOD_A  : natural := 25;
      g_PERIOD_B  : natural := 3;
      g_AMPLITUDE : real := 0.2    );
    port (
      i_clk : in std_logic;
      o_data_even : out std_logic_vector(g_ADC_BITS-1 downto 0);
      o_data_odd  : out std_logic_vector(g_ADC_BITS-1 downto 0)
      );
  end component;


  
    
  --------------------------------
  -- Signals
  --------------------------------
  -- clocks
  signal data_clk, fft_clk, hk_clk : std_logic := '1';
  signal stop : std_logic := '0';

  -- data
  signal data_ew_even, data_ew_odd, data_ns_even, data_ns_odd : std_logic_vector(11 downto 0);
  
  -- spi port
  signal dev_select : std_logic_vector(7 downto 0) := "00000000";
  signal miso, mosi, spi_clk : std_logic := '1';
  
begin

  dut : calibration
    generic map (
      g_CONTROL_SUBSYSTEM_ADDR => "00001100",
      g_READOUT_SUBSYSTEM_ADDR => "00001101",
      LOG2_FFT_LEN         => 5
      )
    port map (
      i_data_clk       => data_clk,
      i_fft_clk        => fft_clk,
      i_hk_fast_clk    => hk_clk,
      i_data_ns_even   => data_ns_even,
      i_data_ns_odd    => data_ns_odd,
      i_data_ew_even   => data_ew_even,
      i_data_ew_odd    => data_ew_odd,
      i_spi_clk        => spi_clk,
      i_dev_select     => dev_select,
      i_spi_mosi       => mosi,
      o_spi_miso       => miso
      );

--  sin_ns : sin_source
--    generic map (
--      g_FREQ_SIG  => 10.0e6,
--      g_AMPLITUDE => 0.3
--      )
--    port map (
--      i_clk  => data_clk,
--      o_data_even => data_ns_even,
--      o_data_odd  => data_ns_odd
--      );
--  
--  sin_ew : sin_source
--    generic map (
--      g_FREQ_SIG  => 22.0e6,
--      g_AMPLITUDE => 0.02
--      )
--    port map (
--      i_clk  => data_clk,
--      o_data_even => data_ew_even,
--      o_data_odd  => data_ew_odd
--      );

  source_10Mhz : sinus_source
    generic map (
      g_PERIOD_A  => 25,
      g_PERIOD_B  => 1,
      g_AMPLITUDE => 0.1
      )
    port map (
      i_clk => data_clk,
      o_data_even => data_ns_even,
      o_data_odd  => data_ns_odd
      );


  
  source_30Mhz : sinus_source
    generic map (
      g_PERIOD_A  => 25,
      g_PERIOD_B  => 3,
      g_AMPLITUDE => 0.1
      )
    port map (
      i_clk => data_clk,
      o_data_even => data_ew_even,
      o_data_odd  => data_ew_odd
      );


--  triangle_ns : triangle_source
--    port map (
--      i_clk => data_clk,
--      o_data_even => data_ns_even,
--      o_data_odd  => data_ns_odd
--      );
--  

  
  p_data_clk : process is
  begin
    if stop = '1' then
      wait;
    else
      data_clk <= not data_clk;
      wait for clk_period_data / 2;
    end if;
  end process;

  p_fft_clk : process is
  begin
    if stop = '1' then
      wait;
    else
      fft_clk <= not fft_clk;
      wait for clk_period_fft / 2;
    end if;
  end process;

  p_hk_clk : process is
  begin
    if stop = '1' then
      wait;
    else
      hk_clk <= not hk_clk;
      wait for clk_period_hk / 2;
    end if;
  end process;


  p_main : process is
  begin
    -- give it some time
    wait for 100 us;

    -- spi transaction to request a readout
    dev_select <= "00001100";
    wait for clk_period_spi / 2;
    for i in 0 to 7 loop
      spi_clk <= '0';
      mosi <= CONTROL_REQ_BREAK(i); -- req break = 1
      wait for clk_period_spi / 2;
      spi_clk <= '1';
      wait for clk_period_spi / 2;
    end loop;
    dev_select <= (others => '0');

    -- read some totals:
    dev_select <= "00001101";
    wait for clk_period_spi / 2;
    for i in 0 to 4 loop
      for j in 0 to 17 loop
        spi_clk <= '0';
        wait for clk_period_spi / 2;
        spi_clk <= '1';
        wait for clk_period_spi / 2;
      end loop;
      wait for clk_period_spi; -- not needed, just easier to read trace
    end loop;
      
    dev_select <= (others => '0');

    -- request a clear
    dev_select <= "00001100";
    wait for clk_period_spi / 2;
    for i in 0 to 7 loop
      spi_clk <= '0';
      mosi <= CONTROL_REQ_CLEAR(i); -- req break = 1, req clear = 1
      wait for clk_period_spi / 2;
      spi_clk <= '1';
      wait for clk_period_spi / 2;
    end loop;
    dev_select <= (others => '0');
    
    -- continue fft's
    dev_select <= "00001100";
    wait for clk_period_spi / 2;
    for i in 0 to 7 loop
      spi_clk <= '0';
      mosi <= CONTROL_CONTINUE(i); -- req break = 0
      wait for clk_period_spi / 2;
      spi_clk <= '1';
      wait for clk_period_spi / 2;
    end loop;
    dev_select <= (others => '0');
    


    
    -- wait some some
    wait for 45 us;
    

    
    stop <= '1';
    wait;
  end process;
  
end behave;
      
      
  

  
  
