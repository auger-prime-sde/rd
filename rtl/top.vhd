--- AUGER radio extension FPGA toplevel design


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
  generic (
    -- Number of data bits from the ADC channels
    g_ADC_BITS : natural := 12;
    -- Number of bits in index counters (11 gives 2048 samples stored)
    g_BUFFER_INDEXSIZE : natural := 11 );

  port (
    -- signals for data streamer
    i_data_in           : in std_logic_vector (g_ADC_BITS-1 downto 0);
    i_adc_clk           : in std_logic;
    i_slow_clk          : in std_logic;
    i_rst               : in std_logic;
    i_trigger           : in std_logic;
    i_start_transfer    : in std_logic;
    o_tx_data           : out std_logic_vector(1 downto 0);
    o_tx_clk            : out std_logic;
    o_tx_datavalid      : out std_logic;
    -- signals for eeprom
    i_flash_miso       : in std_logic;
    o_flash_mosi       : out std_logic;
    o_flash_ce         : out std_logic;
    -- signals to/from science ADC
    io_adc_dio          : inout std_logic;
    o_adc_ce            : out std_logic;
    o_adc_clk           : out std_logic;
    -- signals for housekeeping
    i_housekeeping_clk  : in std_logic;
    i_housekeeping_mosi : in std_logic;
    i_housekeeping_ce   : in std_logic;
    o_housekeeping_miso : out std_logic;
    o_housekeeping_dout : out std_logic_vector(7 downto 0)
    );
  end top;

architecture behaviour of top is
  constant c_STORAGE_WIDTH : natural := 2*g_ADC_BITS;

  signal adc_data : std_logic_vector(c_STORAGE_WIDTH-1 downto 0);

  signal internal_clk : std_logic;
  signal tx_clk : std_logic;

  signal r_flash_clk : std_logic;
  signal r_flash_ce : std_logic;
    

  component adc_driver
    port (
      clkin  : in  std_logic; reset: in  std_logic; sclk: out  std_logic;
      datain : in  std_logic_vector(g_ADC_BITS-1 downto 0);
      q      : out std_logic_vector(c_STORAGE_WIDTH-1 downto 0)
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

  
  component data_streamer
    generic (
    -- Number of data bits from the ADC channels
    g_ADC_BITS : natural := 12;
    -- Number of bits in index counters (11 gives 2048 samples stored)
    g_BUFFER_INDEXSIZE : natural := 11 );

    port (
      i_adc_data       : in std_logic_vector(2*g_ADC_BITS-1 downto 0);
      i_clk            : in std_logic;
      i_tx_clk         : in std_logic;
      i_rst            : in std_logic;
      i_trigger        : in std_logic;
      i_start_transfer : in std_logic;
      o_tx_data        : out std_logic_vector(1 downto 0);
      o_tx_clk         : out std_logic;
      o_tx_datavalid   : out std_logic
    );
  end component;

  component housekeeping
    generic (g_DEV_SELECT_BITS : natural := 8);
    port (
      i_sample_clk          : in    std_logic;
      i_housekeeping_clk    : in    std_logic;
      i_housekeeping_mosi   : in    std_logic;
      o_housekeeping_miso   : out   std_logic;
      i_housekeeping_ce     : in    std_logic;
      o_gpio_data           : out   std_logic_vector(7 downto 0);
      o_flash_clk           : out   std_logic;
      i_flash_miso          : in    std_logic;
      o_flash_mosi          : out   std_logic;
      o_flash_ce            : out   std_logic;
      o_adc_clk             : out   std_logic;
      io_adc_dio            : inout std_logic;
      o_adc_ce              : out   std_logic
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
      CLKOP: out std_logic
    );
  end component;




begin

  o_flash_ce <= r_flash_ce;
  
  tx_clock_synthesizer : tx_clock_pll
    port map (
      CLKI => i_slow_clk,
      CLKOP => tx_clk);

  adc_driver_1 : adc_driver
    port map (
      clkin  => i_adc_clk,
      reset  => i_rst,
      sclk   => internal_clk,
      datain => i_data_in,
      q      => adc_data);
  
  u1: USRMCLK port map (
    USRMCLKI => r_flash_clk,
    USRMCLKTS => r_flash_ce);


  housekeeping_1 : housekeeping
    generic map (g_DEV_SELECT_BITS => 8)
    port map (
      i_sample_clk        => i_slow_clk,
      i_housekeeping_clk  => i_housekeeping_clk,
      i_housekeeping_mosi => i_housekeeping_mosi,
      o_housekeeping_miso => o_housekeeping_miso,
      i_housekeeping_ce   => i_housekeeping_ce,
      o_gpio_data         => o_housekeeping_dout,
      o_flash_clk         => r_flash_clk,
      i_flash_miso        => i_flash_miso,
      o_flash_mosi        => o_flash_mosi,
      o_flash_ce          => r_flash_ce,
      o_adc_clk           => o_adc_clk,
      io_adc_dio          => io_adc_dio,
      o_adc_ce            => o_adc_ce
      );
  
  data_streamer_1 : data_streamer
    generic map (g_BUFFER_INDEXSIZE => g_BUFFER_INDEXSIZE, g_ADC_BITS => g_ADC_BITS)
    port map (
      i_adc_data       => adc_data,
      i_clk            => internal_clk,
      i_tx_clk         => tx_clk,
      i_rst            => i_rst,
      i_trigger        => i_trigger,
      i_start_transfer => i_start_transfer,
      o_tx_data        => o_tx_data,
      o_tx_clk         => o_tx_clk,
      o_tx_datavalid   => o_tx_datavalid );

end;
