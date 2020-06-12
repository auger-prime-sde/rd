--- AUGER radio extension FPGA toplevel design

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library ecp5u;
use ecp5u.components.all;


entity top is
  generic (
    -- Number of data bits from the ADC channels
    g_ADC_BITS         : natural := 12;
    -- Number of bits in index counters (11 gives 2048 samples stored on each channel)
    g_BUFFER_INDEXSIZE : natural := 11);

  port (
    -- signals for adc driver:
    i_data_in           : in std_logic_vector (g_ADC_BITS-1 downto 0);
    i_adc_clk           : in std_logic;
    -- signals for data streamer
    i_xtal_clk          : in std_logic;
    i_trigger           : in std_logic;
    o_tx_data           : out std_logic_vector(1 downto 0);
    o_tx_clk            : out std_logic;
    -- signals for eeprom
    i_hk_flash_miso     : in std_logic;
    o_hk_flash_mosi     : out std_logic;
    o_hk_flash_ce       : out std_logic;
    -- signals to/from science ADC
    i_hk_adc_miso       : in std_logic;
    o_hk_adc_mosi       : out std_logic;
    o_hk_adc_ce         : out std_logic;
    o_hk_adc_clk        : out std_logic;
    o_hk_adc_reset      : out std_logic;
    -- signals for housekeeping
    i_hk_uub_clk        : in std_logic;
    i_hk_uub_mosi       : in std_logic;
    i_hk_uub_ce         : in std_logic;
    o_hk_uub_miso       : out std_logic;
    -- signals for gpio from housekeeping
    o_hk_gpio           : out std_logic_vector(7 downto 0);
    -- signal to/from housekeeping i2c adc:
    io_ads1015_sda      : inout std_logic;
    io_ads1015_scl      : inout std_logic;
    -- signal to/from housekeeping i2c temp sensor:
    io_si7060_sda       : inout std_logic;
    io_si7060_scl       : inout std_logic;
    -- TODO: put this as one of the gpio lines, for now this is tied high
    o_ns_bias_en        : out std_logic;
    o_ew_bias_en        : out std_logic;
    -- leds
    o_led_ns            : out std_logic;
    o_led_ew            : out std_logic
    );
end top;


architecture behaviour of top is
  
  -- wires from adc driver to data streamer:
  signal w_adc_data  : std_logic_vector(4*(g_ADC_BITS+1)-1 downto 0);
  signal w_triangle_even, w_triangle_odd  : std_logic_vector(g_ADC_BITS-1 downto 0);

  signal
    w_data_ns_even,
    w_data_ns_odd,
    w_data_ew_even,
    w_data_ew_odd,
    w_data_ns_even_accumulated,
    w_data_ns_odd_accumulated,
    w_data_ew_even_accumulated,
    w_data_ew_odd_accumulated : std_logic_vector(g_ADC_BITS-1 downto 0);
  
  signal w_ddr_clk   : std_logic;
  signal w_accumulator_clk : std_logic;


  -- wires for internal spi connections
  --signal w_adc_clk   : std_logic;
  --signal w_adc_ce    : std_logic;
  --signal w_adc_mosi  : std_logic;
  signal w_flash_clk : std_logic;
  signal w_flash_ce  : std_logic;
  -- miso and mosi are directly connected to pins

  --signal fast_clk    : std_logic;??
  -- wire for fast 50MHz housekeeping clock used in some parts of housekeeping
  signal w_hk_fast_clk : std_logic;
  
  -- wire for transmission clock
  signal w_tx_clk : std_logic;

  constant c_ADC_RESET_CYCLES: natural := 5e6;-- 10 times per second at 50MHz
  signal r_adc_rst_count : natural := 0;
  signal r_adc_rst : std_logic := '1';

  signal r_hk_trig_out : std_logic;
  signal w_trigger : std_logic_vector(0 to 3);
  
  signal start_offset : std_logic_vector(15 downto 0);
     
  component adc_driver
    port (alignwd: in  std_logic; clkin: in  std_logic; 
        ready: out  std_logic; sclk: out  std_logic; 
        start: in  std_logic; sync_clk: in  std_logic; 

        sync_reset: in  std_logic; 
        datain: in  std_logic_vector(12 downto 0); 
        q: out  std_logic_vector(51 downto 0));
  end component;


  component ddr_unscrambler
    port (
      i_data : in std_logic_vector(51 downto 0);
      o_data_ns_even : out std_logic_vector(11 downto 0);
      o_data_ns_odd  : out std_logic_vector(11 downto 0);
      o_data_ew_even : out std_logic_vector(11 downto 0);
      o_data_ew_odd  : out std_logic_vector(11 downto 0);
      o_trigger      : out std_logic_vector(0 to 3));
  end component;
  
  component triangle_source is
    generic (g_ADC_BITS : natural := 12);
    port (
      i_clk : in std_logic;
      o_data_even : out std_logic_vector(g_ADC_BITS-1 downto 0);
      o_data_odd  : out std_logic_vector(g_ADC_BITS-1 downto 0)
      );
  end component;

  component test_source is
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

  component housekeeping
    generic (g_DEV_SELECT_BITS : natural := 8; g_ADC_BITS : natural := 12);
    port (
      i_hk_fast_clk  : in   std_logic;
      i_hk_uub_clk   : in   std_logic;
      i_hk_uub_mosi  : in   std_logic;
      o_hk_uub_miso  : out  std_logic;
      i_hk_uub_ce    : in   std_logic;
      o_gpio_data    : out  std_logic_vector(7 downto 0);
      o_flash_clk    : out  std_logic;
      i_flash_miso   : in   std_logic;
      o_flash_mosi   : out  std_logic;
      o_flash_ce     : out  std_logic;
      o_adc_clk      : out  std_logic;
      i_adc_miso     : in   std_logic;
      o_adc_mosi     : out  std_logic;
      o_adc_ce       : out  std_logic;
      i_data_clk     : in   std_logic;
      i_data_ns_even : in std_logic_vector(g_ADC_BITS-1 downto 0);
      i_data_ew_even : in std_logic_vector(g_ADC_BITS-1 downto 0);
      i_data_ns_odd  : in std_logic_vector(g_ADC_BITS-1 downto 0);
      i_data_ew_odd  : in std_logic_vector(g_ADC_BITS-1 downto 0);
      i_data_extra   : in std_logic_vector(3 downto 0);
      o_start_offset : out std_logic_vector(15 downto 0);
      io_ads1015_sda : inout std_logic;
      io_ads1015_scl : inout std_logic;
      io_si7060_sda  : inout std_logic;
      io_si7060_scl  : inout std_logic;
      o_led_ns       : out std_logic;
      o_led_ew       : out std_logic;
      o_bias_ns      : out std_logic;
      o_bias_ew      : out std_logic
      );
  end component;

  component spi_decoder is
    generic (
      g_INPUT_BITS  : natural := 16;
      g_OUTPUT_BITS : natural := 8 );
    port (
      i_spi_clk    : in  std_logic;
      i_spi_mosi   : in  std_logic;
      o_spi_miso   : out std_logic;
      i_spi_ce     : in  std_logic;
      i_clk        : in  std_logic;
      o_data       : out std_logic_vector(g_INPUT_BITS-1 downto 0) := (others => '0');
      i_data       : in  std_logic_vector(g_OUTPUT_BITS-1 downto 0);
      o_recv_count : out std_logic_vector(g_INPUT_BITS-1 downto 0) );
  end component;
  
  component tx_clock_pll
    port (
      CLKI: in std_logic;
      CLKOP: out std_logic;
      CLKOS: out std_logic
    );
  end component;


  -- start of magic MCLK block
  -- (see ECP5 sysCONFIG manual section 6.1.2)
  component USRMCLK
    port(
      USRMCLKI : in std_ulogic;
      USRMCLKTS : in std_ulogic
      );
  end component;
  attribute syn_noprune: boolean ;
  attribute syn_noprune of USRMCLK: component is true;
  -- end of magic block


  
begin

  o_hk_adc_reset <= '0';

  process (w_hk_fast_clk) is
  begin
    if rising_edge(w_hk_fast_clk) then
      r_adc_rst_count <= (r_adc_rst_count+1) mod c_ADC_RESET_CYCLES;
      if r_adc_rst_count = 0 then
        r_adc_rst <= '1';
      else
        r_adc_rst <= '0';
      end if;
    end if;
  end process;
  

  -- connect ce line of flash chip to the correct housekeeping line
  o_hk_flash_ce <= w_flash_ce;


  tx_clock_synthesizer : tx_clock_pll
    port map (
      CLKI => i_xtal_clk,
      CLKOP => w_hk_fast_clk,
      CLKOS => w_tx_clk
      );


  adc_driver_1 : adc_driver
    port map (
      alignwd    => '0',
      clkin      => i_adc_clk,
      ready      => open,
      sclk       => w_ddr_clk,
      start      => '1',
      sync_clk   => w_hk_fast_clk,
      sync_reset => '0',
      datain(11 downto 0) => i_data_in,
      datain(12) => i_trigger,
      q          => w_adc_data
      --q          => open
      );

  ddr_unscrambler_1 : ddr_unscrambler
    port map (
      i_data => w_adc_data,
      o_data_ns_even => w_data_ns_even,
      o_data_ns_odd  => w_data_ns_odd,
      o_data_ew_even => w_data_ew_even,
      o_data_ew_odd  => w_data_ew_odd,
      o_trigger      => w_trigger );
      

--  accumulator_ns : accumulator
--    generic map ( g_WIDTH => g_ADC_BITS,
--                  g_LENGTH => 4)
--    port map (
--      i_clk => w_ddr_clk,
--      i_data_even => w_data_ns_even,
--      i_data_odd  => w_data_ns_odd,
--      --i_data_even => w_triangle_even,
--      --i_data_odd  => w_triangle_odd,
--      o_clk => w_accumulator_clk,
--      o_data_even => w_data_ns_even_accumulated,
--      o_data_odd  => w_data_ns_odd_accumulated);
--
--  accumulator_ew : accumulator
--    generic map ( g_WIDTH => g_ADC_BITS,
--                  g_LENGTH => 4)
--    port map (
--      i_clk => w_ddr_clk,
--      i_data_even => w_data_ew_even,
--      i_data_odd  => w_data_ew_odd,
--      --i_data_even => w_triangle_even,
--      --i_data_odd  => w_triangle_odd,
--      o_clk => open,
--      o_data_even => w_data_ew_even_accumulated,
--      o_data_odd  => w_data_ew_odd_accumulated);
  
  
--  source : triangle_source
--    port map (
--      i_clk   => w_ddr_clk,
--      o_data_even => w_triangle_even,
--      o_data_odd  => w_triangle_odd
--      );
  source : test_source
    port map (
      i_clk   => w_ddr_clk,
      o_data_even => w_triangle_even,
      o_data_odd  => w_triangle_odd
      );

  
    
  u1: USRMCLK
    port map (
      USRMCLKI => w_flash_clk,
      USRMCLKTS => w_flash_ce
      );


  housekeeping_1 : housekeeping
    generic map (
      g_DEV_SELECT_BITS => 8,
      --g_DATA_WIDTH => 4*(g_ADC_BITS+1)
      g_ADC_BITS => g_ADC_BITS
      )
    port map (
      i_hk_fast_clk       => w_hk_fast_clk,
      -- we temporarily silence the housekeeping lines in case the incomming
      -- lines are connected to an LVDS-cmos driver with floating input which
      -- could cause erratic input at these ports which would not be remedied
      -- by a pull-up:
      i_hk_uub_clk        => i_hk_uub_clk,
      i_hk_uub_mosi       => i_hk_uub_mosi,
      o_hk_uub_miso       => o_hk_uub_miso,
      i_hk_uub_ce         => i_hk_uub_ce,
      o_gpio_data         => o_hk_gpio,
      o_flash_clk         => w_flash_clk,
      i_flash_miso        => i_hk_flash_miso,
      o_flash_mosi        => o_hk_flash_mosi,
      o_flash_ce          => w_flash_ce,
      o_adc_clk           => o_hk_adc_clk,
      i_adc_miso          => i_hk_adc_miso,
      o_adc_mosi          => o_hk_adc_mosi,
      o_adc_ce            => o_hk_adc_ce,
      i_data_clk          => w_ddr_clk,
      --i_data_clk          => w_accumulator_clk,
      -- four trigger lines are merged into the data as the 13'th bit of each sample
      --i_data(51)          => w_trigger(3),
      --i_data(38)          => w_trigger(2),
      --i_data(25)          => w_trigger(1),
      --i_data(12)          => w_trigger(0),

      -- in the spi data access the highest bits are sent first and interpreted
      -- as the NS channel by the accompanying tool
      
      -- real data:
      --i_data_ns_even => w_data_ns_even,
      --i_data_ew_even => w_data_ew_even,
      --i_data_ns_odd  => w_data_ns_odd,
      --i_data_ew_odd  => w_data_ew_odd,

      -- uncomment this to use the accumulated data for a longer window
      -- also use w_accumulator_clk instead of w_ddr_clk above
      --i_data(50 downto 39) => w_data_ns_even_accumulated,
      --i_data(37 downto 26) => w_data_ew_even_accumulated,
      --i_data(24 downto 13) => w_data_ns_odd_accumulated,
      --i_data(11 downto  0) => w_data_ew_odd_accumulated,

      -- uncomment this instead if you want perfect triangle waves:
      i_data_ns_even => w_triangle_even,
      i_data_ew_even => w_triangle_even,
      i_data_ns_odd  => w_triangle_odd,
      i_data_ew_odd  => w_triangle_odd,
      i_data_extra   => w_trigger,
      --i_data(50 downto 39) => w_triangle_even,
      --i_data(37 downto 26) => w_triangle_even,
      --i_data(24 downto 13) => w_triangle_odd,
      --i_data(11 downto  0) => w_triangle_odd,

      -- or zeroes:
      --i_data(50 downto 39) => (others => '0'),
      --i_data(37 downto 26) => (others => '0'),
      --i_data(24 downto 13) => (others => '0'),
      --i_data(11 downto  0) => (others => '0'),
      
      o_start_offset      => start_offset,
      io_ads1015_sda      => io_ads1015_sda,
      io_ads1015_scl      => io_ads1015_scl,
      io_si7060_sda       => io_si7060_sda,
      io_si7060_scl       => io_si7060_scl,
      o_led_ns            => o_led_ns,
      o_led_ew            => o_led_ew,
      o_bias_ns           => o_ns_bias_en,
      o_bias_ew           => o_ew_bias_en
    );
  
  data_streamer_1 : data_streamer
    generic map (g_BUFFER_INDEXSIZE => g_BUFFER_INDEXSIZE, g_ADC_BITS => g_ADC_BITS)
    port map (
      -- the data_writer in data_streamer sends the lower bits as channel 1 and
      -- the higher bits as channel 2 which are then interpreted as NS and EW
      -- resp. by rd_scope in the uub. So here NS/EW appear reversed from the
      -- way they are sent to the housekeeping above.

      -- use data lines (normal operations)
      i_adc_data(47 downto 36) => w_data_ew_even(11 downto 0),
      i_adc_data(35 downto 24) => w_data_ns_even(11 downto 0),
      i_adc_data(23 downto 12) => w_data_ew_odd(11 downto 0),
      i_adc_data(11 downto  0) => w_data_ns_odd(11 downto 0),

      -- uncomment this to use the accumulated data for a longer window
      -- also use w_accumulator_clk instead of w_ddr_clk below
      --i_adc_data(47 downto 36) => w_data_ew_even_accumulated,
      --i_adc_data(35 downto 24) => w_data_ns_even_accumulated,
      --i_adc_data(23 downto 12) => w_data_ew_odd_accumulated,
      --i_adc_data(11 downto  0) => w_data_ns_odd_accumulated,
      
      -- uncomment these instead if you want perfect triangle waves
      --i_adc_data(47 downto 37) => w_triangle_even(11 downto 1),
      --i_adc_data(35 downto 25) => w_triangle_even(11 downto 1),
      --i_adc_data(23 downto 13) => w_triangle_odd(11 downto 1),
      --i_adc_data(11 downto  1) => w_triangle_odd(11 downto 1),

      -- put the trigger in the LSB, also change the ranges above
      --i_adc_data(36) => w_trigger(0), -- ew even
      --i_adc_data(24) => w_trigger(1), -- ns even
      --i_adc_data(12) => w_trigger(2), -- ew odd
      --i_adc_data( 0) => w_trigger(3), -- ns odd
      

      -- or zeroes:
      --i_adc_data(47 downto 36) => (others => '0'),
      --i_adc_data(35 downto 24) => (others => '0'),
      --i_adc_data(23 downto 12) => (others => '0'),
      --i_adc_data(11 downto  0) => (others => '0'),
      -- 
      i_clk            => w_ddr_clk,
      --i_clk            => w_accumulator_clk,
      i_tx_clk         => w_tx_clk,
      i_trigger        => w_trigger(3),
      i_trigger_even   => w_trigger(1),
      i_start_transfer => '1',
      i_start_offset   => start_offset(g_BUFFER_INDEXSIZE downto 0),
      o_tx_data        => o_tx_data,
      o_tx_clk         => o_tx_clk );

end;
