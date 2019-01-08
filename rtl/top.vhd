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
    i_data_in        : in std_logic_vector (g_ADC_BITS-1 downto 0);
    i_adc_clk        : in std_logic;
    i_slow_clk       : in std_logic;
    i_rst            : in std_logic;
    i_trigger        : in std_logic;
    i_start_transfer : in std_logic;
    o_tx_data        : out std_logic_vector(1 downto 0);
    o_tx_clk         : out std_logic;
    o_tx_datavalid   : out std_logic);
  end top;

architecture behaviour of top is
  constant c_STORAGE_WIDTH : natural := 2*g_ADC_BITS;

  signal adc_data : std_logic_vector(c_STORAGE_WIDTH-1 downto 0);

  signal internal_clk : std_logic;
  signal uart_clk : std_logic;

  component adc_driver
    port (
      clkin  : in  std_logic; reset: in  std_logic; sclk: out  std_logic;
      datain : in  std_logic_vector(g_ADC_BITS-1 downto 0);
      q      : out std_logic_vector(c_STORAGE_WIDTH-1 downto 0)
    );
  end component;

  component data_streamer
    generic (
    -- Number of data bits from the ADC channels
    g_ADC_BITS : natural := 12;
    -- Number of bits in index counters (11 gives 2048 samples stored)
    g_BUFFER_INDEXSIZE : natural := 11 );

    port (
      i_adc_data       : in std_logic_vector(2*g_ADC_BITS-1 downto 0);
      i_clk            : in std_logic;
      i_uart_clk       : in std_logic;
      i_rst            : in std_logic;
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
      CLKOP: out std_logic
    );
  end component;

begin

clock_divider_uart : tx_clock_pll
  port map (
    CLKI => i_slow_clk,
    CLKOP => uart_clk);

adc_driver_1 : adc_driver
  port map (
    clkin  => i_adc_clk,
    reset  => i_rst,
    sclk   => internal_clk,
    datain => i_data_in,
    q      => adc_data);

data_streamer_1 : data_streamer
  generic map (g_BUFFER_INDEXSIZE => g_BUFFER_INDEXSIZE, g_ADC_BITS => g_ADC_BITS)
  port map (
    i_adc_data     => adc_data,
    i_clk          => internal_clk,
    i_uart_clk     => uart_clk,
    i_rst          => i_rst,
    i_trigger      => i_trigger,
    i_start_transfer => i_start_transfer,
    o_tx_data      => o_tx_data,
    o_tx_clk       => o_tx_clk,
    o_tx_datavalid => o_tx_datavalid);


end;
