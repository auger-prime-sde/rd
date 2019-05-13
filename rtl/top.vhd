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
    -- signals to/from science ADC
    o_hk_adc_mosi       : out std_logic;
    o_hk_adc_ce         : out std_logic;
    o_hk_adc_clk        : out std_logic;
    o_hk_adc_reset      : out std_logic;
    -- TODO: put this as one of the gpio lines, for now this is tied high
    o_bias_t            : out std_logic
    );
end top;


architecture behaviour of top is
  -- wires from adc driver to data streamer:
  signal w_adc_data  : std_logic_vector(4*g_ADC_BITS-1 downto 0);
  signal w_ddr_clk   : std_logic;

  signal w_hk_clk : std_logic;
  
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

  
  component boot_sequence is
  port (
    i_clk     : in std_logic;
    i_rst     : in std_logic;
    o_hk_clk  : out std_logic;
    o_hk_ce   : out std_logic;
    o_hk_mosi : out  std_logic
    );
  end component;

  
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

    
  component tx_clock_pll
    port (
      CLKI: in std_logic;
      CLKOP: out std_logic;
      CLKOS: out std_logic
    );
  end component;



begin

  -- pull bias T high
  o_bias_t <= '1';

  tx_clock_synthesizer : tx_clock_pll
    port map (
      CLKI => i_xtal_clk,
      CLKOP => w_hk_clk,
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
      sync_clk   => w_hk_clk,
      sync_reset => '0',
      datain     => i_data_in,
      q          => w_adc_data);


  boot_sequence_1 : boot_sequence
    port map (
      i_clk  => w_hk_clk,
      i_rst  => '0',
      o_hk_clk => o_hk_adc_clk,
      o_hk_ce  => o_hk_adc_ce,
      o_hk_mosi => o_hk_adc_mosi
      );
  
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
