--- Data streamer module
---
--- This module is in charge of the normal ADC data transfers
---


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity data_streamer is
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
    o_tx_datavalid   : out std_logic);
  end data_streamer;

architecture behaviour of data_streamer is
  signal data_output_bus : std_logic_vector(2*g_ADC_BITS-1 downto 0);
  signal buffer_write_en : std_logic;
  signal buffer_read_en : std_logic;
  signal write_address : std_logic_vector(g_BUFFER_INDEXSIZE-2 downto 0);
  signal read_address : std_logic_vector(g_BUFFER_INDEXSIZE-1 downto 0);
  signal start_address : std_logic_vector(g_BUFFER_INDEXSIZE-1 downto 0);
  signal trigger_done : std_logic;
  signal arm : std_logic;
  signal tx_enable : std_logic;



  
  component data_buffer
    generic (g_DATA_WIDTH, g_ADDRESS_WIDTH : natural);
    port (
      i_write_clk   : in  std_logic;
      i_write_enable: in  std_logic;
      i_write_addr  : in  std_logic_vector(g_BUFFER_INDEXSIZE-2 downto 0);
      i_write_data  : in  std_logic_vector(4*g_ADC_BITS-1 downto 0);
      i_read_clk    : in  std_logic;
      i_read_enable : in  std_logic;
      i_read_addr   : in  std_logic_vector(g_BUFFER_INDEXSIZE-1 downto 0);
      o_read_data   : out std_logic_vector(2*g_ADC_BITS-1 downto 0)
    );
  end component;

  component simple_counter
    generic ( g_SIZE : natural );
    port (
      i_clk: in std_logic;
      o_count: out std_logic_vector(g_BUFFER_INDEXSIZE-2 downto 0)
    );
  end component;

  component data_writer
    generic (g_WORDSIZE: natural);
    port (
      i_data      : in std_logic_vector(2*g_WORDSIZE-1 downto 0);
      i_dataready : in std_logic;
      i_clk       : in std_logic;
      o_data_1    : out std_logic;
      o_data_2    : out std_logic;
      o_valid     : out std_logic;
      o_clk       : out std_logic
    );
  end component;

  component write_controller
    generic (g_ADDRESS_BITS : natural; g_START_OFFSET : natural);
    port (
      i_clk          : in std_logic;
      i_trigger      : in std_logic;
      i_curr_addr    : in std_logic_vector(g_ADDRESS_BITS-1 downto 0);
      i_arm          : in std_logic;
      o_write_en     : out std_logic;
      o_trigger_done : out std_logic;
      o_start_addr   : out std_logic_vector(g_ADDRESS_BITS-1 downto 0)
    );
  end component;

  component readout_controller
    generic (g_ADDRESS_BITS : natural; g_WORDSIZE : natural);
    port (
      i_clk          : in std_logic;
      i_trigger_done : in std_logic;
      i_start_addr   : in std_logic_vector(g_ADDRESS_BITS-1 downto 0);
      o_arm          : out std_logic := '0';
      o_read_enable  : out std_logic := '1';
      o_read_addr    : out std_logic_vector(g_ADDRESS_BITS-1 downto 0);
      o_tx_enable    : out std_logic := '0';
      i_tx_start     : in std_logic
    );
  end component;

begin

write_index_counter : simple_counter
  generic map (g_SIZE => g_BUFFER_INDEXSIZE-1)
  port map (
    i_clk   => i_clk,
    o_count => write_address);

  
data_buffer_1 : data_buffer
  generic map (g_ADDRESS_WIDTH => g_BUFFER_INDEXSIZE, g_DATA_WIDTH => 2*g_ADC_BITS)
  port map (
    i_write_clk    => i_clk,
    i_write_enable => buffer_write_en,
    i_write_addr   => write_address,
    i_read_clk     => i_tx_clk,
    i_read_enable  => buffer_read_en,
    i_read_addr    => read_address,
    -- channel A, first sample, MSB first
    i_write_data(47 downto 36)  => (
      47=>i_adc_data(17),
      46=>i_adc_data(5),
      45=>i_adc_data(16),
      44=>i_adc_data(4),
      43=>i_adc_data(15),
      42=>i_adc_data(3),
      41=>i_adc_data(14),
      40=>i_adc_data(2),
      39=>i_adc_data(13),
      38=>i_adc_data(1),
      37=>i_adc_data(12),
      36=>i_adc_data(0)      ),
    -- channel B, first sample, MSB first
    i_write_data(35 downto 24)  => (
      35=>i_adc_data(23),
      34=>i_adc_data(11),
      33=>i_adc_data(22),
      32=>i_adc_data(10),
      31=>i_adc_data(21),
      30=>i_adc_data(9),
      29=>i_adc_data(20),
      28=>i_adc_data(8),
      27=>i_adc_data(19),
      26=>i_adc_data(7),
      25=>i_adc_data(18),
      24=>i_adc_data(6)      ),
    -- channel A, second sample, MSB first
    i_write_data(23 downto 12)  => (
      23=>i_adc_data(41),
      22=>i_adc_data(29),
      21=>i_adc_data(40),
      20=>i_adc_data(28),
      19=>i_adc_data(39),
      18=>i_adc_data(27),
      17=>i_adc_data(38),
      16=>i_adc_data(26),
      15=>i_adc_data(37),
      14=>i_adc_data(25),
      13=>i_adc_data(36),
      12=>i_adc_data(24)      ),
    -- channel B, second sample, MSB first
    i_write_data(11 downto 0)  => (
      11=>i_adc_data(47),
      10=>i_adc_data(35),
      9 =>i_adc_data(46),
      8 =>i_adc_data(34),
      7 =>i_adc_data(45),
      6 =>i_adc_data(33),
      5 =>i_adc_data(44),
      4 =>i_adc_data(32),
      3 =>i_adc_data(43),
      2 =>i_adc_data(31),
      1 =>i_adc_data(42),
      0 =>i_adc_data(30)      ),
    o_read_data    => data_output_bus);

data_writer_1 : data_writer
  generic map (g_WORDSIZE => g_ADC_BITS)
  port map (
    i_data         => data_output_bus,
    i_dataready    => tx_enable,
    i_clk          => i_tx_clk,
    o_data_1       => o_tx_data(0),
    o_data_2       => o_tx_data(1),
    o_valid        => o_tx_datavalid,
    o_clk          => o_tx_clk);

write_controller_1 : write_controller
  generic map (g_ADDRESS_BITS => g_BUFFER_INDEXSIZE, g_START_OFFSET => 1024)
  port map (
    i_clk                                         => i_clk,
    i_trigger                                     => i_trigger,
    i_curr_addr(g_BUFFER_INDEXSIZE-1 downto 1)    => write_address,
    i_curr_addr(0)                                => '0',
    i_arm                                         => arm,
    o_write_en                                    => buffer_write_en,
    o_start_addr                                  => start_address,
    o_trigger_done                                => trigger_done);

readout_controller_1 : readout_controller
  generic map (g_ADDRESS_BITS => g_BUFFER_INDEXSIZE, g_WORDSIZE => g_ADC_BITS)
  port map (
    i_clk          => i_tx_clk,
    i_trigger_done => trigger_done,
    i_start_addr   => start_address,
    o_arm          => arm,
    o_read_enable  => buffer_read_en,
    o_read_addr    => read_address,
    o_tx_enable    => tx_enable,
    i_tx_start     => i_start_transfer);

end;
