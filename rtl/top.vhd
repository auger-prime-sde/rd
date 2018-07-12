--- AUGER radio extension FPGA toplevel design

library ieee;
use ieee.std_logic_1164.all;

entity top is
  generic (
    -- Number of data bits from the ADC channels
    g_ADC_BITS : natural := 12;
    -- Number of bits in index counters (11 gives 2048 samples stored)
    g_BUFFER_INDEXSIZE : natural := 11;
    -- Number of bits in serial words
    g_UART_WORDSIZE : natural := 7  );
  port (
    dataIn : in std_logic_vector (g_ADC_BITS-1 downto 0);
    dataOvIn : in std_logic;
    clk : in std_logic;
    rst : in std_logic;

    o_led : out std_logic);
end top;

architecture behaviour of top is
  constant c_SAMPLE_WIDTH : natural := g_ADC_BITS+1;
  constant c_STORAGE_WIDTH : natural := 2*c_SAMPLE_WIDTH;

  signal adc_input_bus : std_logic_vector(c_SAMPLE_WIDTH-1 downto 0);
  signal adc_data : std_logic_vector(c_STORAGE_WIDTH-1 downto 0);
  signal data_output_bus : std_logic_vector(c_STORAGE_WIDTH-1 downto 0);

  signal clk_intern : std_logic;
  signal write_address : std_logic_vector(g_BUFFER_INDEXSIZE-1 downto 0);
  signal read_address : std_logic_vector(g_BUFFER_INDEXSIZE-1 downto 0);

  component adc_driver
    port (
      clkin: in  std_logic; reset: in  std_logic; sclk: out  std_logic;
      datain: in  std_logic_vector(c_SAMPLE_WIDTH-1 downto 0);
      q: out  std_logic_vector(c_STORAGE_WIDTH-1 downto 0)
    );
  end component;

  component data_buffer
    generic (g_DATA_WIDTH, g_ADDRESS_WIDTH : natural);
    port (
      i_wclk : in std_logic;
      i_we : in std_logic;
      i_waddr : in std_logic_vector(g_BUFFER_INDEXSIZE-1 downto 0);
      i_wdata : in std_logic_vector(c_STORAGE_WIDTH-1 downto 0);
      i_rclk : in std_logic;
      i_re: in std_logic;
      i_raddr : in std_logic_vector(g_BUFFER_INDEXSIZE-1 downto 0);
      o_rdata : out std_logic_vector(c_STORAGE_WIDTH-1 downto 0)
    );
  end component;

  component simple_counter
    generic ( g_SIZE : natural );
    port (
      i_clk: in std_logic;
      o_q: out std_logic_vector(g_BUFFER_INDEXSIZE-1 downto 0)
    );
  end component;

  component settable_counter
    generic ( g_SIZE : natural );
    port (
      i_en     : in std_logic;
      i_clk    : in std_logic;
      i_set    : in std_logic;
      i_data   : in std_logic_vector(g_BUFFER_INDEXSIZE-1 downto 0);
      o_data   : out std_logic_vector(g_BUFFER_INDEXSIZE-1 downto 0)
    );
  end component;

  component uart_expander
    generic (g_WORDSIZE: natural; g_WORDCOUNT : natural);
    port (
      i_data      : in std_logic_vector(g_WORDCOUNT*g_WORDSIZE-1 downto 0);
      i_dataready : in std_logic;
      i_clk       : in std_logic;
      o_data      : out std_logic := '1';
      o_ready     : out std_logic := '1'
    );
  end component;
begin

  adc_input_bus <= dataOvIn & dataIn;

adc_driver_1 : adc_driver
  port map (
    clkin => clk,
    reset => rst,
    sclk => clk_intern,
    datain =>  adc_input_bus,
    q => adc_data);

write_index_counter : simple_counter
  generic map (g_SIZE => g_BUFFER_INDEXSIZE)
  port map (
    i_clk => clk_intern,
    o_q => write_address);

read_index_counter : settable_counter
  generic map (g_SIZE => g_BUFFER_INDEXSIZE)
  port map (
    i_clk => clk_intern,
  o_data => read_address,
  i_en => '1',
  i_set => '0',
  i_data => (others => '0'));

data_buffer_1 : data_buffer
  generic map (g_ADDRESS_WIDTH => g_BUFFER_INDEXSIZE, g_DATA_WIDTH => c_STORAGE_WIDTH)
  port map (
    i_wclk => clk_intern,
    i_we => '1',
    i_waddr => write_address,
    i_rclk => clk_intern,
    i_re => '1',
    i_raddr => read_address,
    i_wdata => adc_data,
    o_rdata => data_output_bus);


uart_1 : uart_expander
  generic map (g_WORDSIZE => g_UART_WORDSIZE, g_WORDCOUNT => 4)
  port map (
    -- TODO: do this more generic:
    i_data(12 downto 0)   => data_output_bus(12 downto 0),
    i_data(26 downto 14)  => data_output_bus(25 downto 13),
    i_data(13)            => '0',
    i_data(27)            => '0',
    i_dataready => '0',
    i_clk       => '0',
    o_data      => o_led,
    o_ready     => open
    );

  --o_led <= data_output_bus(0);
end;
