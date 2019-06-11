library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity housekeeping is
  generic ( g_DEV_SELECT_BITS : natural :=  8 );
  port (
    i_hk_fast_clk        : in  std_logic; -- 50 MHz for internal operations
    -- signals to/from UUB:
    i_hk_uub_clk  : in  std_logic;
    i_hk_uub_mosi : in  std_logic;
    o_hk_uub_miso : out std_logic;
    i_hk_uub_ce   : in  std_logic;
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
    i_adc_miso          : in std_logic;
    o_adc_mosi          : out std_logic;
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

  -- internal lines between boot seq and spi selector
  signal r_boot_clk : std_logic;
  signal r_boot_ce  : std_logic;
  signal r_boot_mosi: std_logic;

  -- internal lines between spi selector and spi demuxer
  signal r_internal_clk : std_logic;
  signal r_internal_ce  : std_logic;
  signal r_internal_mosi: std_logic;

  -- wires for flash
  signal r_flash_ce : std_logic;
  
  -- wires for adc:
  signal r_adc_ce         : std_logic;


  component spi_demux is
    generic ( g_DEV_SELECT_BITS : natural := g_DEV_SELECT_BITS );
    port (
      i_spi_clk    : in  std_logic;
      i_hk_fast_clk: in  std_logic;
      i_spi_mosi   : in  std_logic;
      i_spi_ce     : in  std_logic;
      o_spi_clk    : out std_logic;
      o_spi_mosi   : out std_logic;
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

  component boot_sequence is
  port (
    i_clk     : in  std_logic;
    i_rst     : in  std_logic;
    i_hk_clk  : in  std_logic;
    i_hk_ce   : in  std_logic;
    i_hk_mosi : in  std_logic;
    o_hk_clk  : out std_logic;
    o_hk_ce   : out std_logic;
    o_hk_mosi : out std_logic
    );
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
  o_flash_clk    <= r_internal_clk when r_flash_ce = '0' else '1';
  o_flash_mosi   <= r_internal_mosi when r_flash_ce = '0' else '1';
  
  -- wiring adc: 
  o_adc_ce       <= r_adc_ce;
  o_adc_clk      <= r_internal_clk;
  o_adc_mosi     <= r_internal_mosi;

  -- mux the housekeeping output miso depending on the selected peripheral 
  o_hk_uub_miso <=
    i_flash_miso when r_flash_ce='0' else 
    i_adc_miso   when r_adc_ce='0' else r_gpio_miso;


  -- instantiate one boot sequence injector:
  boot_sequence_1 : boot_sequence
    port map (
      i_clk     => i_hk_fast_clk,
      i_rst     => '1',
      i_hk_clk  => i_hk_uub_clk,
      i_hk_ce   => i_hk_uub_ce,
      i_hk_mosi => i_hk_uub_mosi,
      o_hk_clk  => r_boot_clk,
      o_hk_ce   => r_boot_ce,
      o_hk_mosi => r_boot_mosi
    );
  
  -- instantiate one spi demuxer
  spi_demux_1 : spi_demux
    generic map (g_DEV_SELECT_BITS => g_DEV_SELECT_BITS)
    port map (
      i_spi_clk     => r_boot_clk,
      i_hk_fast_clk => i_hk_fast_clk,
      i_spi_mosi    => r_boot_mosi,
      i_spi_ce      => r_boot_ce,
      o_spi_clk     => r_internal_clk,
      o_spi_mosi    => r_internal_mosi,
      o_dev_select  => r_subsystem_select
      );


  -- instantiate one spi_decoder and one gpio subsystem
  spi_decoder_gpio : spi_decoder
    generic map (
      g_INPUT_BITS => 16,
      g_OUTPUT_BITS => 8
      )
    port map (
      i_spi_clk    => r_internal_clk,
      i_spi_mosi   => r_internal_mosi,
      o_spi_miso   => r_gpio_miso,
      i_spi_ce     => r_gpio_ce,
      i_clk        => i_hk_fast_clk,
      o_data       => r_gpio_in,
      i_data       => r_gpio_out,
      o_recv_count => r_gpio_count
      );


  
  digitalout_1 : Digitaloutput
    generic map (
      g_CMD_BITS => 8,
      g_DATA_IN_BITS => 8,
      g_DATA_OUT_BITS => 8
      )
    port map (
      i_clk         => i_hk_fast_clk,
      i_enable      => r_gpio_trigger,
      i_cmd         => r_gpio_in(15 downto 8),
      i_data        => r_gpio_in(7 downto 0),
      o_data        => r_gpio_out
      );
      
  
  
  
end behaviour;
  
