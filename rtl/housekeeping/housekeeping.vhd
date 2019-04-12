library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity housekeeping is
  generic ( g_DEV_SELECT_BITS : natural :=  8 );
  port (
    i_sample_clk        : in  std_logic; -- 50 MHz for internal operations
    -- signals to/from UUB:
    i_housekeeping_clk  : in  std_logic;
    i_housekeeping_mosi : in  std_logic;
    o_housekeeping_miso : out std_logic;
    i_housekeeping_ce   : in  std_logic;
    -- pins to/from subsystems:
    -- digitalout:
    o_gpio_data         : out std_logic_vector(7 downto 0);
    -- flash:
    o_flash_clk         : out std_logic;
    i_flash_miso        : in  std_logic;
    o_flash_mosi        : out std_logic;
    o_flash_ce          : out std_logic;
    -- science adc
    o_adc_clk           : out std_logic;
    io_adc_dio          : inout std_logic;
    o_adc_ce            : out std_logic
    );

  

end housekeeping;


architecture behaviour of housekeeping is
  -- internal wires to select subsystem
  signal r_subsystem_select : std_logic_vector(g_DEV_SELECT_BITS-1 downto 0);
  
  -- internal wires for gpio:
  signal r_gpio_in      : std_logic_vector(15 downto 0);
  signal r_gpio_out     : std_logic_vector( 7 downto 0);
  signal r_gpio_count   : std_logic_vector(15 downto 0);
  signal r_gpio_trigger : std_logic;
  signal r_gpio_ce      : std_logic;
  signal r_gpio_miso    : std_logic;

  -- wires for flash
  signal r_flash_ce : std_logic;
  
  -- wires for adc:
  signal r_adc_ce         : std_logic;
  signal r_adc_recv_count : std_logic_vector(23 downto 0);
  signal r_adc_tx_phase   : std_logic;


  component spi_demux is
    generic ( g_DEV_SELECT_BITS : natural := g_DEV_SELECT_BITS );
    port (
      i_spi_clk    : in  std_logic;
      i_sample_clk : in  std_logic;
      i_spi_mosi   : in  std_logic;
      i_spi_ce     : in  std_logic;
      o_dev_select : out std_logic_vector(g_DEV_SELECT_BITS-1 downto 0) := (others => '0')
      );
  end component;

  component spi_decoder is
    generic (
      g_INPUT_BITS  : natural := 32;
      g_OUTPUT_BITS : natural := 32 );
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

  component Digitaloutput is
    generic (
      g_CMD_BITS        : natural := 8;  
      g_DATA_IN_BITS    : natural := 8;
      g_DATA_OUT_BITS   : natural := 8;
      g_DEFAULT_OUTPUT  : std_logic_vector (7 downto 0) := "11111111" --we only use the last 8 bits for output so default all outputs are high
      );
    port(	--inputs
      i_clk : in std_logic;
      i_enable : in std_logic;
      i_cmd : in std_logic_vector(g_CMD_BITS-1 downto 0);
      i_data : in std_logic_vector(g_DATA_IN_BITS-1 downto 0);
      
      --outputs
      o_data : out std_logic_vector (g_DATA_OUT_BITS-1 downto 0) := g_DEFAULT_OUTPUT; 
      o_busy	  : out std_logic
      );
  end component;
begin

  -- make sub-system select lines
  r_gpio_ce      <= '0' when r_subsystem_select = std_logic_vector(to_unsigned(1, g_DEV_SELECT_BITS)) else '1';
  r_flash_ce     <= '0' when r_subsystem_select = std_logic_vector(to_unsigned(2, g_DEV_SELECT_BITS)) else '1';
  r_adc_ce       <= '0' when r_subsystem_select = std_logic_vector(to_unsigned(3, g_DEV_SELECT_BITS)) else '1';

  -- wiring the gpio:
  r_gpio_trigger <= '1' when r_gpio_count = std_logic_vector(to_unsigned(15, 16)) else '0';
  o_gpio_data    <= r_gpio_out(7 downto 0);
  
    
  -- wiring flash:
  o_flash_ce     <= r_flash_ce;
  o_flash_clk    <= i_housekeeping_clk;
  o_flash_mosi   <= i_housekeeping_mosi;
  
  -- wiring adc: 
  o_adc_ce       <= r_adc_ce;
  o_adc_clk      <= i_housekeeping_clk;
  io_adc_dio     <= i_housekeeping_mosi when r_adc_tx_phase = '0' else 'Z';
  r_adc_tx_phase <= '0' when to_integer(unsigned(r_adc_recv_count)) < 16 else '1';

  -- mux the housekeeping output miso depending on the selected peripheral 
  o_housekeeping_miso <=
    i_flash_miso when r_flash_ce='0'
    else r_gpio_miso when r_adc_ce = '1'
    else io_adc_dio when r_adc_tx_phase = '1'
    else '0'; 

  
  -- instantiate one spi demuxer
  spi_demux_1 : spi_demux
    generic map (g_DEV_SELECT_BITS => g_DEV_SELECT_BITS)
    port map (
      i_spi_clk    => i_housekeeping_clk,
      i_sample_clk => i_sample_clk,
      i_spi_mosi   => i_housekeeping_mosi,
      i_spi_ce     => i_housekeeping_ce,
      o_dev_select => r_subsystem_select
      );


  -- instantiate one spi_decoder and one gpio subsystem
  spi_decoder_gpio : spi_decoder
    generic map (
      g_INPUT_BITS => 16,
      g_OUTPUT_BITS => 8
      )
    port map (
      i_spi_clk    => i_housekeeping_clk,
      i_spi_mosi   => i_housekeeping_mosi,
      o_spi_miso   => r_gpio_miso,
      i_spi_ce     => r_gpio_ce,
      i_clk        => i_sample_clk,
      o_data       => r_gpio_in,
      i_data       => r_gpio_out,
      o_recv_count => r_gpio_count
      );


  spi_decoder_adc : spi_decoder
    generic map (
      -- this is not true but we abuse the decoder for it's progress counter to
      -- distinguish between the read and the write phase
      g_INPUT_BITS => 24,
      g_OUTPUT_BITS => 1
      )
    port map (
      i_spi_clk    => i_housekeeping_clk,
      i_spi_mosi   => i_housekeeping_mosi,
      o_spi_miso   => open,
      i_spi_ce     => r_adc_ce,
      i_clk        => i_sample_clk,
      o_data       => open,
      i_data       => (others =>'0'),
      o_recv_count => r_adc_recv_count
      );
  

  
  digitalout_1 : Digitaloutput
    generic map (
      g_CMD_BITS => 8,
      g_DATA_IN_BITS => 8,
      g_DATA_OUT_BITS => 8
      )
    port map (
      i_clk         => i_sample_clk,
      i_enable      => r_gpio_trigger,
      i_cmd         => r_gpio_in(15 downto 8),
      i_data        => r_gpio_in(7 downto 0),
      o_data        => r_gpio_out
      );
      
  
  
  
end behaviour;
  
