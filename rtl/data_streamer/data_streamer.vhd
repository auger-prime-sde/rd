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
    g_BUFFER_INDEXSIZE : natural := 11
    );
  port (
    i_adc_data       : in std_logic_vector(4*g_ADC_BITS-1 downto 0);
    i_clk            : in std_logic;
    i_tx_clk         : in std_logic;
    i_trigger        : in std_logic;
    i_trigger_even   : in std_logic;
    i_start_transfer : in std_logic;
    i_start_offset   : in std_logic_vector(g_BUFFER_INDEXSIZE downto 0);
    o_tx_data        : out std_logic_vector(1 downto 0);
    o_tx_clk         : out std_logic;
    o_trigger_done   : out std_logic
    );
  end data_streamer;

architecture behaviour of data_streamer is
  signal data_output_bus : std_logic_vector(2*g_ADC_BITS-1 downto 0);
  signal buffer_write_en : std_logic;
  signal buffer_read_en : std_logic;
  signal write_address : std_logic_vector(g_BUFFER_INDEXSIZE-1 downto 0); 
  signal read_address : std_logic_vector(g_BUFFER_INDEXSIZE downto 0);
  signal start_address : std_logic_vector(g_BUFFER_INDEXSIZE downto 0);
  signal trigger_done : std_logic;
  signal arm : std_logic;
  signal tx_enable : std_logic;
  signal clk_padding : std_logic;
  signal r_trigger_odd : std_logic;

  
  component data_buffer
    generic (g_DATA_WIDTH, g_ADDRESS_WIDTH : natural);
    port (
      i_write_clk   : in  std_logic;
      i_write_enable: in  std_logic;
      i_write_addr  : in  std_logic_vector(g_ADDRESS_WIDTH-2 downto 0);
      i_write_data  : in  std_logic_vector(2*g_DATA_WIDTH-1 downto 0);
      i_read_clk    : in  std_logic;
      i_read_enable : in  std_logic;
      i_read_addr   : in  std_logic_vector(g_ADDRESS_WIDTH-1 downto 0);
      o_read_data   : out std_logic_vector(g_DATA_WIDTH-1 downto 0)
    );
  end component;

 
  component simple_counter
    generic ( g_SIZE : natural );
    port (
      i_clk: in std_logic;
      o_count: out std_logic_vector(g_SIZE-1 downto 0)
    );
  end component;

  component data_writer
    generic (g_WORDSIZE: natural);
    port (
      i_data        : in std_logic_vector(2*g_WORDSIZE-1 downto 0);
      i_dataready   : in std_logic;
      i_clk         : in std_logic;
      i_clk_padding : in std_logic;
      o_data_1      : out std_logic;
      o_data_2      : out std_logic;
      o_clk         : out std_logic
    );
  end component;

  
  component write_controller
    generic (g_ADDRESS_BITS : natural);
    port (
      i_clk          : in std_logic;
      i_trigger      : in std_logic;
      i_curr_addr    : in std_logic_vector(g_ADDRESS_BITS-1 downto 0);
      i_arm          : in std_logic;
      i_start_offset : in std_logic_vector(g_ADDRESS_BITS-1 downto 0);
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
      o_clk_padding  : out std_logic := '0';
      o_tx_enable    : out std_logic := '0';
      i_tx_start     : in std_logic
    );
  end component;

begin
  r_trigger_odd <= not i_trigger_even; 
  o_trigger_done <= trigger_done;

write_index_counter : simple_counter
  generic map (g_SIZE => g_BUFFER_INDEXSIZE)
  port map (
    i_clk   => i_clk,
    o_count => write_address);

  
data_buffer_1 : data_buffer
  generic map (g_ADDRESS_WIDTH => g_BUFFER_INDEXSIZE+1, g_DATA_WIDTH => 2*g_ADC_BITS)
  port map (
    i_write_clk    => i_clk,
    i_write_enable => buffer_write_en,
    i_write_addr   => write_address,
    i_read_clk     => i_tx_clk,
    i_read_enable  => buffer_read_en,
    i_read_addr    => read_address,
    -- channel A, first sample, MSB first
    i_write_data(51 downto 39)  => (
      51=>i_adc_data(12), -- smuggled trigger bit
      50=>i_adc_data(18),
      49=>i_adc_data( 5),
      48=>i_adc_data(17),
      47=>i_adc_data( 4),
      46=>i_adc_data(16),
      45=>i_adc_data( 3),
      44=>i_adc_data(15),
      43=>i_adc_data( 2),
      42=>i_adc_data(14),
      41=>i_adc_data( 1),
      40=>i_adc_data(13),
      39=>i_adc_data( 0)     ),
    -- channel B, first sample, MSB first
    i_write_data(38 downto 26)  => (
      38=>i_adc_data(25), -- smuggled trigger bit
      37=>i_adc_data(24),
      36=>i_adc_data(11),
      35=>i_adc_data(23),
      34=>i_adc_data(10),
      33=>i_adc_data(22),
      32=>i_adc_data( 9),
      31=>i_adc_data(21),
      30=>i_adc_data( 8),
      29=>i_adc_data(20),
      28=>i_adc_data( 7),
      27=>i_adc_data(19),
      26=>i_adc_data( 6)       ),
    -- channel A, second sample, MSB first
    i_write_data(25 downto 13)  => (
      25=>i_adc_data(38), -- smuggled trigger bit
      24=>i_adc_data(44),
      23=>i_adc_data(31),
      22=>i_adc_data(43),
      21=>i_adc_data(30),
      20=>i_adc_data(42),
      19=>i_adc_data(29),
      18=>i_adc_data(41),
      17=>i_adc_data(28),
      16=>i_adc_data(40),
      15=>i_adc_data(27),
      14=>i_adc_data(39),
      13=>i_adc_data(26)      ),
    -- channel B, second sample, MSB first
    i_write_data(12 downto 0)  => (
      12=>i_adc_data(51), -- smuggled trigger bit
      11=>i_adc_data(50),
      10=>i_adc_data(37),
      9 =>i_adc_data(49),
      8 =>i_adc_data(36),
      7 =>i_adc_data(48),
      6 =>i_adc_data(35),
      5 =>i_adc_data(47),
      4 =>i_adc_data(34),
      3 =>i_adc_data(46),
      2 =>i_adc_data(33),
      1 =>i_adc_data(45),
      0 =>i_adc_data(32)      ),
    o_read_data    => data_output_bus);

data_writer_1 : data_writer
  generic map (g_WORDSIZE => g_ADC_BITS)
  port map (
    i_data         => data_output_bus,
    i_dataready    => tx_enable,
    i_clk          => i_tx_clk,
    i_clk_padding  => clk_padding,
    o_data_1       => o_tx_data(0),
    o_data_2       => o_tx_data(1),
    o_clk          => o_tx_clk);

write_controller_1 : write_controller
  generic map (g_ADDRESS_BITS => g_BUFFER_INDEXSIZE+1)
  port map (
    i_clk                                         => i_clk,
    i_trigger                                     => i_trigger,
    i_curr_addr(g_BUFFER_INDEXSIZE downto 1)      => write_address,
    i_curr_addr(0)                                => r_trigger_odd,
    i_arm                                         => arm,
    i_start_offset                                => i_start_offset,
    o_write_en                                    => buffer_write_en,
    o_start_addr                                  => start_address,
    o_trigger_done                                => trigger_done);

readout_controller_1 : readout_controller
  generic map (g_ADDRESS_BITS => g_BUFFER_INDEXSIZE+1, g_WORDSIZE => g_ADC_BITS)
  port map (
    i_clk          => i_tx_clk,
    i_trigger_done => trigger_done,
    i_start_addr   => start_address,
    o_arm          => arm,
    o_read_enable  => buffer_read_en,
    o_read_addr    => read_address,
    o_clk_padding  => clk_padding,
    o_tx_enable    => tx_enable,
    i_tx_start     => i_start_transfer);

end;
