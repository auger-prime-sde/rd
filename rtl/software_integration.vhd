--- AUGER radio extension FPGA toplevel design

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity software_integration is
  generic (
    -- Number of data bits from the ADC channels
    g_ADC_BITS : natural := 12;
    -- ADC interface width
    g_ADC_DRIVER_BITS : natural := 14;
    -- Number of bits in index counters (11 gives 2048 samples stored)
    g_BUFFER_INDEXSIZE : natural := 11;
    -- Number of bits in serial words
    g_UART_WORDSIZE : natural := 7  );
  port (
    i_data : in std_logic_vector (2*(g_ADC_BITS+1)-1 downto 0);
    clk_intern : in std_logic;
    clk_uart : in std_logic;
    trigger : in std_logic;
    i_start_transfer : in std_logic;
    o_transfer_done : out std_logic;
    o_data : out std_logic);
end software_integration;

architecture behaviour of software_integration is
  constant c_SAMPLE_WIDTH : natural := g_ADC_BITS+1;
  constant c_STORAGE_WIDTH : natural := 2*c_SAMPLE_WIDTH;
  constant c_CLOCK_DIVIDER : natural := 1736;
  constant c_CLOCK_SIZE    : natural := 11;
  constant c_ADC_DRIVER_WIDTH : natural := g_ADC_DRIVER_BITS+1;
  constant c_ADC_DRIVER_OUTPUT_WIDTH : natural := 2*c_ADC_DRIVER_WIDTH;

  signal data_output_bus : std_logic_vector(c_STORAGE_WIDTH-1 downto 0) := (others => '0');

  signal buffer_write_en : std_logic;
  signal buffer_read_en : std_logic;
  signal write_address : std_logic_vector(g_BUFFER_INDEXSIZE-1 downto 0);
  signal read_address : std_logic_vector(g_BUFFER_INDEXSIZE-1 downto 0);
  signal read_set_address : std_logic_vector(g_BUFFER_INDEXSIZE-1 downto 0);

  signal write_trigger_done : std_logic;
  signal write_arm : std_logic;

  signal uart_ready : std_logic;
  signal uart_dataready : std_logic;

  component data_buffer
    generic (g_DATA_WIDTH, g_ADDRESS_WIDTH : natural);
    port (
      i_write_clk : in std_logic;
      i_write_enable : in std_logic;
      i_write_addr : in std_logic_vector(g_BUFFER_INDEXSIZE-1 downto 0);
      i_write_data : in std_logic_vector(c_STORAGE_WIDTH-1 downto 0);
      i_read_clk : in std_logic;
      i_read_enable: in std_logic;
      i_read_addr : in std_logic_vector(g_BUFFER_INDEXSIZE-1 downto 0);
      o_read_data : out std_logic_vector(c_STORAGE_WIDTH-1 downto 0)
    );
  end component;

  component simple_counter
    generic ( g_SIZE : natural );
    port (
      i_clk: in std_logic;
      o_count: out std_logic_vector(g_BUFFER_INDEXSIZE-1 downto 0)
    );
  end component;

  component uart_expander
    generic (g_WORDSIZE: natural; g_WORDCOUNT : natural);
    port (
      i_data      : in std_logic_vector(g_WORDCOUNT*g_WORDSIZE-1 downto 0);
      i_dataready : in std_logic;
      i_clk       : in std_logic;
      o_data      : out std_logic;
      o_ready     : out std_logic
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
    generic (g_ADDRESS_BITS : natural);
    port (
      i_clk          : in std_logic;
      i_trigger_done : in std_logic;
      i_start_addr   : in std_logic_vector(g_ADDRESS_BITS-1 downto 0);
      o_arm          : out std_logic := '1';
      o_read_enable  : out std_logic := '1';
      o_read_addr    : out std_logic_vector(g_ADDRESS_BITS-1 downto 0);
      i_uart_ready   : in std_logic;
      o_data_next    : out std_logic := '0';
      o_data_ready   : out std_logic := '1';
      i_tx_start     : in std_logic
    );
  end component;

begin

  


write_index_counter : simple_counter
  generic map (g_SIZE => g_BUFFER_INDEXSIZE)
  port map (
    i_clk   => clk_intern,
    o_count => write_address);

data_buffer_1 : data_buffer
  generic map (g_ADDRESS_WIDTH => g_BUFFER_INDEXSIZE, g_DATA_WIDTH => c_STORAGE_WIDTH)
  port map (
    i_write_clk => clk_intern,
    i_write_enable => buffer_write_en,
    i_write_addr => write_address,
    i_read_clk => clk_uart,
    i_read_enable => buffer_read_en,
    i_read_addr => read_address,
    i_write_data => i_data,
    o_read_data => data_output_bus);

uart_1 : uart_expander
  generic map (g_WORDSIZE => g_UART_WORDSIZE, g_WORDCOUNT => 4)
  port map (
    -- TODO: do this more generic:
    i_data(12 downto 0)   => data_output_bus(12 downto 0),
    i_data(26 downto 14)  => data_output_bus(25 downto 13),
    i_data(13)            => '0',
    i_data(27)            => '0',
    i_dataready => uart_dataready,
    i_clk       => clk_uart,
    o_data      => o_data,
    o_ready     => uart_ready
    );

write_controller_1 : write_controller
  generic map (g_ADDRESS_BITS => g_BUFFER_INDEXSIZE, g_START_OFFSET => 1024)
  port map (
    i_clk => clk_intern,
    i_trigger => trigger,
    i_curr_addr => write_address,
    i_arm => write_arm,
    o_write_en => buffer_write_en,
    o_start_addr => read_set_address,
    o_trigger_done => write_trigger_done
    );

  readout_controller_1 : readout_controller
    generic map (g_ADDRESS_BITS => g_BUFFER_INDEXSIZE)
    port map (
      i_clk          => clk_uart,
      i_trigger_done => write_trigger_done,
      i_start_addr   => read_set_address,
      o_arm          => write_arm,
      o_read_enable  => buffer_read_en,
      o_read_addr    => read_address,
      i_uart_ready   => uart_ready,
      o_data_next    => uart_dataready,
      o_data_ready   => o_transfer_done,
      i_tx_start     => i_start_transfer
   );

end;
