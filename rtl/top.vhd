--- AUGER radio extension FPGA toplevel design

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
  generic (
    -- Number of data bits from the ADC channels
    g_ADC_BITS : natural := 12;
    -- Number of bits in index counters (11 gives 2048 samples stored on each channel)
    g_BUFFER_INDEXSIZE : natural := 11 );

  port (
    -- signals for adc driver:
    i_data_in           : in std_logic_vector (g_ADC_BITS-1 downto 0);
    i_adc_clk           : in std_logic;
    -- signals for data streamer
    i_xtal_clk          : in std_logic;
    i_trigger           : in std_logic;
    o_tx_data           : out std_logic_vector(1 downto 0);
    o_tx_clk            : out std_logic;
    o_tx_datavalid      : out std_logic;
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
    -- TODO: put this as one of the gpio lines, for now this is tied high
    o_bias_t            : out std_logic
    );
end top;


architecture behaviour of top is
  -- wires from adc driver to data streamer:
  signal w_adc_data  : std_logic_vector(4*g_ADC_BITS-1 downto 0);
  signal w_ddr_clk   : std_logic;

  -- wires for internal spi connections
  signal w_adc_clk   : std_logic;
  signal w_adc_ce    : std_logic;
  signal w_adc_mosi  : std_logic;
  signal w_flash_clk : std_logic;
  signal w_flash_ce  : std_logic;
  -- miso and mosi are directly connected to pins

  --signal fast_clk    : std_logic;??
  -- wire for fast 50MHz housekeeping clock used in some parts of housekeeping
  signal w_hk_fast_clk : std_logic;
  
  -- wire for transmission clock
  signal w_tx_clk : std_logic;

    
  component adc_driver
    port (alignwd: in  std_logic; clkin: in  std_logic; 
        ready: out  std_logic; sclk: out  std_logic; 
        start: in  std_logic; sync_clk: in  std_logic; 

        sync_reset: in  std_logic; 
        datain: in  std_logic_vector(11 downto 0); 
        q: out  std_logic_vector(47 downto 0));
  end component;

  component adc_boot
    port (
      i_hk_fast_clk  : in  std_logic;
      i_hk_adc_clk   : in  std_logic;
      i_hk_adc_ce    : in  std_logic;
      i_hk_adc_mosi  : in  std_logic;
      o_hk_adc_reset : out std_logic;
      o_hk_adc_clk   : out std_logic;
      o_hk_adc_ce    : out std_logic;
      o_hk_adc_mosi  : out std_logic
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
      i_adc_data       : in std_logic_vector(4*g_ADC_BITS-1 downto 0);
      i_clk            : in std_logic;
      i_tx_clk         : in std_logic;
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
      o_adc_ce       : out  std_logic
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


  signal r_hk_clk  : std_logic;
  signal r_hk_ce   : std_logic;
  signal r_hk_mosi : std_logic;
  attribute syn_keep: boolean;
  attribute syn_keep of r_hk_mosi,r_hk_ce,r_hk_clk: signal is true;

  --signal w_10M_clk : std_logic;
  --constant c_TX_CLK_DIV : natural := 10;
  --signal r_tx_clk_count : natural range 0 to c_TX_CLK_DIV-1;
  
begin

  -- pull bias T high
  o_bias_t <= '1';

  -- connect ce line of flash chip to the correct housekeeping line
  o_hk_flash_ce <= w_flash_ce;

  
  process(i_xtal_clk) is
  begin
    r_hk_mosi <= i_hk_uub_mosi;
    r_hk_ce   <= i_hk_uub_ce;
    r_hk_clk  <= i_hk_uub_clk;
  end process;

  --process(w_10M_clk) is
  --begin
  --  if rising_edge(w_10M_clk) then
  --    r_tx_clk_count <= (r_tx_clk_count + 1) mod c_TX_CLK_DIV;
  --    if r_tx_clk_count = 0 then
  --      w_tx_clk <= not w_tx_clk;
  --    end if;
  --  end if;
  --end process;
  
  
    
  tx_clock_synthesizer : tx_clock_pll
    port map (
      CLKI => i_xtal_clk,
      CLKOP => w_hk_fast_clk,
      CLKOS => w_tx_clk
      --CLKOP => w_hk_fast_clk,
      --CLKOS => w_10M_clk
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
      datain     => i_data_in,
      q          => w_adc_data);

  adc_boot_1 : adc_boot
    port map (
      i_hk_fast_clk  => w_hk_fast_clk,
      i_hk_adc_clk   => w_adc_clk,
      i_hk_adc_ce    => w_adc_ce,
      i_hk_adc_mosi  => w_adc_mosi,
      o_hk_adc_reset => o_hk_adc_reset,
      o_hk_adc_clk   => o_hk_adc_clk,
      o_hk_adc_ce    => o_hk_adc_ce,
      o_hk_adc_mosi  => o_hk_adc_mosi
      );
  
  u1: USRMCLK port map (
    USRMCLKI => w_flash_clk,
    USRMCLKTS => w_flash_ce);


  housekeeping_1 : housekeeping
    generic map (g_DEV_SELECT_BITS => 8)
    port map (
      i_hk_fast_clk       => w_hk_fast_clk,
      -- we temporarily silence the housekeeping lines in case the incomming
      -- lines are connected to an LVDS-cmos driver with floating input which
      -- could cause erratic input at these ports which would not be remedied
      -- by a pull-up:
      i_hk_uub_clk        => '1',--i_hk_uub_clk,
      i_hk_uub_mosi       => '1',--i_hk_uub_mosi,
      o_hk_uub_miso       => o_hk_uub_miso,
      i_hk_uub_ce         => '1',--i_hk_uub_ce,
      o_gpio_data         => o_hk_gpio,
      o_flash_clk         => w_flash_clk,
      i_flash_miso        => i_hk_flash_miso,
      o_flash_mosi        => o_hk_flash_mosi,
      o_flash_ce          => w_flash_ce,
      o_adc_clk           => w_adc_clk,
      i_adc_miso          => i_hk_adc_miso,
      o_adc_mosi          => w_adc_mosi,
      o_adc_ce            => w_adc_ce      );
  
  data_streamer_1 : data_streamer
    generic map (g_BUFFER_INDEXSIZE => g_BUFFER_INDEXSIZE, g_ADC_BITS => g_ADC_BITS)
    port map (
      i_adc_data       => w_adc_data,
      i_clk            => w_ddr_clk,
      i_tx_clk         => w_tx_clk,
      i_trigger        => i_trigger,
      i_start_transfer => '1',
      o_tx_data        => o_tx_data,
      o_tx_clk         => o_tx_clk,
      o_tx_datavalid   => o_tx_datavalid );

end;
