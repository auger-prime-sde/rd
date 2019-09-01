library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity housekeeping is
  generic ( g_DEV_SELECT_BITS : natural :=  8 );
  port (
    i_hk_fast_clk        : in  std_logic; -- 100 MHz for internal operations
    -- signals to/from UUB:
    i_hk_uub_clk  : in  std_logic;
    i_hk_uub_mosi : in  std_logic;
    o_hk_uub_miso : out std_logic;
    i_hk_uub_ce   : in  std_logic;
    -- trigger a housekeeping data refresh
    i_trigger     : in std_logic;
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
    o_adc_ce            : out std_logic;
    -- housekeeping adc
    io_hk_sda           : inout std_logic;
    io_hk_scl           : inout std_logic 
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

  -- internal wires for i2c:
  signal r_i2c_in       : std_logic_vector(23 downto 0);
  signal r_i2c_out      : std_logic_vector(63 downto 0);
  signal r_i2c_count    : std_logic_vector(23 downto 0);
  signal r_i2c_trigger  : std_logic;
  signal r_i2c_ce       : std_logic;
  signal r_i2c_miso     : std_logic;
  
  signal r_i2c_clk      : std_logic;
  signal r_ads1015_data : t_i2c_word;
  signal r_ads1015_valid: std_logic;
  signal r_ads1015_next : std_logic;

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


  component i2c2 is
    generic (
      g_ADDR          : std_logic_vector(6 downto 0)
      );
    port(	--inputs
      i_clk      : in std_logic;
      i_data     : in t_i2c_word;
      i_valid    : in std_logic;
      --outputs
      o_data     : out std_logic_vector (7 downto 0);
      o_next     : out std_logic;
      -- i2c interface
      sda	     : inout std_logic := 'Z';
      scl	     : inout std_logic := 'Z'
      );
  end component;

  component read_sequence is
    generic (
      g_SEQ_DATA : t_i2c_data
      );
    port (
      i_clk      : in std_logic;
      i_trig     : in std_logic;
      i_next     : in std_logic;
      o_data     : out t_i2c_word;
      o_valid    : out std_logic
      );
  end component;


  
  component bootsequence is
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
      g_DATA_BITS    : natural := 8;
      g_DEFAULT_OUTPUT  : std_logic_vector (7 downto 0) := "11111111" --we only use the last 8 bits for output so default all outputs are high
      );
    port(	--inputs
      i_clk : in std_logic;
      i_enable : in std_logic;
      i_cmd : in std_logic_vector(g_CMD_BITS-1 downto 0);
      i_data : in std_logic_vector(g_DATA_BITS-1 downto 0);
      
      --outputs
      o_data : out std_logic_vector (g_DATA_BITS-1 downto 0) := g_DEFAULT_OUTPUT; 
      o_busy	  : out std_logic
      );
  end component;

  component clock_divider is
    generic (
      g_MAX_COUNT : natural);
    port (
      i_clk: in std_logic;
      o_clk: out std_logic);
  end component;
  
begin


  -- make sub-system select lines
  r_gpio_ce      <= '0' when r_subsystem_select = std_logic_vector(to_unsigned(1, g_DEV_SELECT_BITS)) else '1';
  r_flash_ce     <= '0' when r_subsystem_select = std_logic_vector(to_unsigned(2, g_DEV_SELECT_BITS)) else '1';
  r_adc_ce       <= '0' when r_subsystem_select = std_logic_vector(to_unsigned(3, g_DEV_SELECT_BITS)) else '1';
  r_i2c_ce       <= '0' when r_subsystem_select = std_logic_vector(to_unsigned(4, g_DEV_SELECT_BITS)) else '1';

  
  -- wiring the gpio:
  r_gpio_trigger <= '1' when r_gpio_count = std_logic_vector(to_unsigned(15, 16)) else '0';
  o_gpio_data    <= r_gpio_out(7 downto 0);

  -- wiring the i2c adc:
  r_i2c_trigger <= '1' when r_i2c_count = std_logic_vector(to_unsigned(20, 24)) else '0';
    
  -- wiring flash:
  o_flash_ce     <= r_flash_ce;
  o_flash_clk    <= r_internal_clk when r_flash_ce = '0' else '1';
  o_flash_mosi   <= r_internal_mosi when r_flash_ce = '0' else '1';
  
  -- wiring adc:
  -- we force the clock to be silent when not inside a transaction
  -- to reduce noise. and because the clock edge on which the ce line goes low
  -- is seen as a negative edge by the adc and we want to make sure that this
  -- neg edge is not accidentally picked up. Note that for the latter is it
  -- important that we force the clock to '0'. This is in contrast to the
  -- diagrams in the ADC datasheet but it should not matter what the value is.
  o_adc_ce       <= r_adc_ce;
  o_adc_clk      <= not r_internal_clk when r_adc_ce = '0' else '0'; 
  o_adc_mosi     <= r_internal_mosi when r_adc_ce = '0' else '0';

  -- select the housekeeping output miso depending on the selected peripheral 
  o_hk_uub_miso <=
    (i_flash_miso and r_flash_ce) or
    (i_adc_miso   and r_adc_ce  ) or
    (r_gpio_miso  and r_gpio_ce ) or
    (r_i2c_miso   and r_i2c_ce);
    
  

  -- instantiate one boot sequence injector:
  bootsequence_1 : bootsequence
    port map (
      i_clk     => i_hk_fast_clk,
      i_rst     => '0',
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

  spi_decoder_i2c : spi_decoder
    generic map (
      g_INPUT_BITS  => 24,
      g_OUTPUT_BITS => 64
      )
    port map (
      i_spi_clk    => r_internal_clk,
      i_spi_mosi   => r_internal_mosi,
      o_spi_miso   => r_i2c_miso,
      i_spi_ce     => r_i2c_ce,
      i_clk        => i_hk_fast_clk,
      o_data       => r_i2c_in,
      i_data       => r_i2c_out,
      o_recv_count => r_i2c_count
      );

  clock_divider_i2c : clock_divider
    generic map (
      g_MAX_COUNT => 250 -- from 100 MHz to 400 kHz
      )
    port map (
      i_clk => i_hk_fast_clk,
      o_clk => r_i2c_clk
      );

  read_sequence_ads1015 : read_sequence
    generic map (
      g_SEQ_DATA => ((data => "00000001", restart => '0', rw => '0'),-- select config register
                     (data => "10000101", restart => '0', rw => '0'),-- trigger conversion
                     (data => "10000000", restart => '0', rw => '0'),-- keep rest at default
                     (data => "00000000", restart => '1', rw => '0'),-- select conversion register
                     (data => "XXXXXXXX", restart => '1', rw => '1'),
                     (data => "XXXXXXXX", restart => '0', rw => '1'))
      )
    port map (
      i_clk      => r_i2c_clk,
      i_trig     => i_trigger,
      i_next     => r_ads1015_next,
      o_data     => r_ads1015_data,
      o_valid    => r_ads1015_valid
      );
  
  i2c2_ads1015 : i2c2
    generic map (
      g_ADDR     => "1001000"
      )
    port map (
      i_clk      => r_i2c_clk,
      i_data     => r_ads1015_data,
      i_valid    => r_ads1015_valid,
      o_data     => open,
      o_next     => r_ads1015_next,
      sda	     => io_hk_sda,
      scl	     => io_hk_scl
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
      g_DATA_BITS => 8
      )
    port map (
      i_clk         => i_hk_fast_clk,
      i_enable      => r_gpio_trigger,
      i_cmd         => r_gpio_in(15 downto 8),
      i_data        => r_gpio_in(7 downto 0),
      o_data        => r_gpio_out
      );
      
  
  
  
end behaviour;
  
