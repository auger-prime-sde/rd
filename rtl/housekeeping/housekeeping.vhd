library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;


entity housekeeping is
  generic (
    g_DEV_SELECT_BITS : natural :=  8;
    g_DATA_WIDTH : natural
    );
  port (
    i_hk_fast_clk        : in  std_logic; -- 100 MHz for internal operations
    -- signals to/from UUB:
    i_hk_uub_clk  : in  std_logic;
    i_hk_uub_mosi : in  std_logic;
    o_hk_uub_miso : out std_logic;
    i_hk_uub_ce   : in  std_logic;
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
    -- raw capture via spi:
    i_data_clk          : in std_logic;
    i_data              : in std_logic_vector(g_DATA_WIDTH-1 downto 0);
    -- output for trigger offset
    o_start_offset      : out std_logic_vector(15 downto 0);
    -- housekeeping adc
    io_ads1015_sda      : inout std_logic;
    io_ads1015_scl      : inout std_logic;
    -- housekeeping temp sens
    io_si7060_sda       : inout std_logic;
    io_si7060_scl       : inout std_logic;
    -- leds
    o_led_ns            : out std_logic;
    o_led_ew            : out std_logic;
    -- bias enable
    o_bias_ns           : out std_logic;
    o_bias_ew           : out std_logic
    );
end housekeeping;


architecture behaviour of housekeeping is

  -- for debugging
  signal r_reveal_clk : std_logic;

  -- trigger for housekeeping
  signal r_periodic_trigger : std_logic;
  signal r_artificial_trigger : std_logic;
  signal r_trigger : std_logic;
  
  -- internal wires to select subsystem
  signal r_subsystem_select : std_logic_vector(g_DEV_SELECT_BITS-1 downto 0);
  
  -- wires for raw capture via spi block
  signal r_capture_miso : std_logic;
  
  -- internal wires for gpio:
  signal r_gpio_in      : std_logic_vector(15 downto 0);
  signal r_gpio_out     : std_logic_vector( 7 downto 0);
  signal r_gpio_count   : std_logic_vector(15 downto 0);
  signal r_gpio_trigger : std_logic;
  signal r_gpio_ce      : std_logic;
  signal r_gpio_miso    : std_logic;
  -- signals for bias dis/en-able
  signal r_bias_miso    : std_logic;

  -- wires for version info block:
  signal r_version_miso : std_logic;

  -- wires for start offset register:
  signal r_offset_miso : std_logic;

  -- internal wires for i2c:
  signal r_ads1015_miso : std_logic;
  signal r_si7060_miso  : std_logic;
  signal r_ads1015_data : std_logic_vector(63 downto 0);
  signal r_i2c_clk      : std_logic;
  
  -- internal lines between boot seq and spi selector
  signal r_boot_clk : std_logic;
  signal r_boot_ce  : std_logic;
  signal r_boot_mosi: std_logic;

  -- internal lines between spi selector and spi demuxer
  signal r_internal_clk : std_logic;
  signal r_internal_ce  : std_logic;
  signal r_internal_mosi: std_logic;

  -- wires for flash
  signal r_flash_ce   : std_logic;
  signal r_flash_miso : std_logic;
  
  -- wires for adc:
  signal r_adc_clk    : std_logic;
  signal r_adc_ce     : std_logic;
  signal r_adc_miso   : std_logic;

  


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
      g_SUBSYSTEM_ADDR : std_logic_vector;
      g_DEFAULT_OUTPUT : std_logic_vector (7 downto 0) := "11111111" 
      );
    port(	--inputs
      i_clk : in std_logic;
      i_spi_clk : in std_logic;
      i_spi_mosi : in std_logic;
      o_spi_miso : out std_logic;
      i_dev_select : in std_logic_vector(g_SUBSYSTEM_ADDR'length-1 downto 0);
    
      --outputs
      o_data : out std_logic_vector (g_DEFAULT_OUTPUT'length-1 downto 0) := g_DEFAULT_OUTPUT
      );  
  end component;

  component clock_divider is
    generic (
      g_MAX_COUNT : natural);
    port (
      i_clk: in std_logic;
      o_clk: out std_logic);
  end component;
  
  component i2c_wrapper is
    generic (
      g_SUBSYSTEM_ADDR : std_logic_vector;
      g_CLK_DIV : natural := 125; -- 400 kHz
      g_SEQ_DATA : t_i2c_data
    );
    port (
      -- clock
      i_hk_fast_clk : in std_logic;
      -- trigger
      i_trigger     : in std_logic;
      -- spi interface
      i_spi_clk     : in std_logic;
      i_spi_mosi    : in std_logic;
      o_spi_miso    : out std_logic;
      i_dev_select  : in std_logic_vector(g_SUBSYSTEM_ADDR'length-1 downto 0);
      
      -- i2c interface
      io_hk_sda     : inout std_logic;
      io_hk_scl     : inout std_logic;

      -- parellel out
      o_latched     : out std_logic_vector(63 downto 0)
      );
  end component;

  component status_led is
    generic (
      g_MIN_VOLTAGE: natural;
      g_MAX_VOLTAGE: natural
      );
    port (
      i_clk : in std_logic;
      i_data : in std_logic_vector(31 downto 0);
      o_led : out std_logic
      );
    end component;

  component  spi_wrapper is
    generic (
      g_SUBSYSTEM_ADDR : std_logic_vector
      );
    port (
      -- interface in the direction of the uub
      i_clk        : in std_logic;
      i_mosi       : in std_logic;
      o_miso       : out std_logic;
      i_dev_select : in std_logic_vector(g_SUBSYSTEM_ADDR'length-1 downto 0);
      -- interface in the direction of the spi device
      o_clk        : out std_logic;
      o_mosi       : out std_logic;
      i_miso: in std_logic;
      o_ce         : out std_logic
      );
  end component;

  component fake_trigger is
    generic (
    g_SUBSYSTEM_ADDR : std_logic_vector
    );
  port (
    i_hk_fast_clk : in std_logic;
    i_spi_clk     : in std_logic;
    i_spi_mosi    : in std_logic;
    o_spi_miso    : out std_logic;
    i_dev_select  : in std_logic_vector(g_SUBSYSTEM_ADDR'length-1 downto 0);
    o_trigger     : out std_logic
    );
  end component;


  component version_info is
    generic (
      g_SUBSYSTEM_ADDR : std_logic_vector;
      g_VERSION : std_logic_vector(7 downto 0)
      );
    port (
      -- clock
      i_hk_fast_clk : in std_logic;
      -- spi interface
      i_spi_clk     : in std_logic;
      i_spi_mosi    : in std_logic;
      o_spi_miso    : out std_logic;
      i_dev_select  : in std_logic_vector(g_SUBSYSTEM_ADDR'length-1 downto 0)
      );
  end component;

  component spi_register is
    generic (
      g_SUBSYSTEM_ADDR : std_logic_vector;
      g_REGISTER_WIDTH : natural := 8
      );
    port (
      i_hk_fast_clk : in std_logic;
      i_spi_clk : in std_logic;
      i_spi_mosi : in std_logic;
      o_spi_miso : out std_logic;
      i_dev_select : in std_logic_vector(g_SUBSYSTEM_ADDR'length-1 downto 0);
      o_value: out std_logic_vector(g_REGISTER_WIDTH-1 downto 0)
      );
  end component;
      
  component periodic_trigger is
    generic (
      g_PERIOD : natural;
      g_HIGH : natural
      );
    port (
      i_clk: in std_logic;
      o_trig: out std_logic
      );
    end component;
  

  component spi_capture is
    generic (g_SUBSYSTEM_ADDR : std_logic_vector;
             g_DATA_WIDTH: natural;
             g_BUFFER_LEN: natural );
    port ( i_spi_clk : in std_logic;
           i_spi_mosi : in std_logic;
           o_spi_miso : out std_logic;
           i_dev_select : in std_logic_vector(g_SUBSYSTEM_ADDR'length-1 downto 0);
           -- raw data
           i_data : in std_logic_vector(g_DATA_WIDTH-1 downto 0);
           i_data_clk : in std_logic);
  end component;


begin

  -- adc has inverted clock polarity
  r_adc_clk <= not r_internal_clk;

  -- select the housekeeping output miso depending on the selected peripheral 
  o_hk_uub_miso <= r_flash_miso or r_adc_miso or r_gpio_miso or r_ads1015_miso or r_si7060_miso or r_version_miso or r_offset_miso or r_fft_miso or r_capture_miso or r_bias_miso;

  --r_trigger is the combination of periodic and artificial triggers
  r_trigger <= r_periodic_trigger or r_artificial_trigger;
  --r_trigger <= r_artificial_trigger;
  
  periodic_trigger_1 : periodic_trigger
    generic map (
      g_PERIOD => 500000000,-- 5 seconds at 100 MHz
      g_HIGH   => 500 -- more than one clk at 800 khz (how fast the i2c
                      -- wrappers poll the trigger input.
      )
    port map (
      i_clk => i_hk_fast_clk,
      o_trig => r_periodic_trigger
      );
      

  spi_wrapper_flash : spi_wrapper
    generic map (
      g_SUBSYSTEM_ADDR => "00000010"
      )
    port map (
      i_clk            => r_internal_clk,
      i_mosi           => r_internal_mosi,
      o_miso           => r_flash_miso,
      i_dev_select     => r_subsystem_select,
      o_clk            => o_flash_clk,
      o_mosi           => o_flash_mosi,
      i_miso           => i_flash_miso,
      o_ce             => o_flash_ce
      );

  -- Note on wiring adc:
  -- we force the clock to be silent when not inside a transaction
  -- to reduce noise. and because the clock edge on which the ce line goes low
  -- is seen as a negative edge by the adc and we want to make sure that this
  -- neg edge is not accidentally picked up. Note that for the latter is it
  -- important that we force the clock to '0'. This is in contrast to the
  -- diagrams in the ADC datasheet but it should not matter what the value is.
  spi_wrapper_adc : spi_wrapper
    generic map (
      g_SUBSYSTEM_ADDR => "00000011"
      )
    port map (
      i_clk            => r_adc_clk,
      i_mosi           => r_internal_mosi,
      o_miso           => r_adc_miso,
      i_dev_select     => r_subsystem_select,
      o_clk            => o_adc_clk,
      o_mosi           => o_adc_mosi,
      i_miso           => i_adc_miso,
      o_ce             => o_adc_ce
      );

  

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

  
  clock_divider_reveal : clock_divider
    generic map (
      g_MAX_COUNT => 10 -- from 100 MHz to 10 MHz
      )
    port map (
      i_clk => i_hk_fast_clk,
      o_clk => r_reveal_clk
      );


  -- The ADS1015 at it's maximum conversion speed (3300 SPS) takes 0.315 uS to
  -- complete a conversion. This conversion starts immediately after the config
  -- register is written. At 400kHz, 0.315uS is 126 clock cycles. I2C uses 9
  -- clock cycles per byte so we have to inject 14 dummies after the trigger
  -- before reading the result.
  ads1015_1 : i2c_wrapper
    generic map (
      g_SUBSYSTEM_ADDR => "00000100",
      g_CLK_DIV =>  125,
      g_SEQ_DATA => (
        -- write mux and trigger:
        (data => "10010000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000001", restart => '0', dir => '0', ack=>'X', addr => "XXX"),
        (data => "11000011", restart => '0', dir => '0', ack=>'X', addr => "XXX"),
        (data => "11100000", restart => '0', dir => '0', ack=>'X', addr => "XXX"),
        -- stall 
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        -- read result
        (data => "10010000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '0', dir => '0', ack=>'X', addr => "XXX"),
        (data => "10010001", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "XXXXXXXX", restart => '0', dir => '1', ack=>'0', addr => "000"),
        (data => "XXXXXXXX", restart => '0', dir => '1', ack=>'0', addr => "001"),

        -- write mux and trigger:
        (data => "10010000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000001", restart => '0', dir => '0', ack=>'X', addr => "XXX"),
        (data => "11010011", restart => '0', dir => '0', ack=>'X', addr => "XXX"),
        (data => "11100000", restart => '0', dir => '0', ack=>'X', addr => "XXX"),
        -- stall 
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        -- read result
        (data => "10010000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '0', dir => '0', ack=>'X', addr => "XXX"),
        (data => "10010001", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "XXXXXXXX", restart => '0', dir => '1', ack=>'0', addr => "010"),
        (data => "XXXXXXXX", restart => '0', dir => '1', ack=>'0', addr => "011"),

        -- write mux and trigger:
        (data => "10010000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000001", restart => '0', dir => '0', ack=>'X', addr => "XXX"),
        (data => "11100011", restart => '0', dir => '0', ack=>'X', addr => "XXX"),
        (data => "11100000", restart => '0', dir => '0', ack=>'X', addr => "XXX"),
        -- stall 
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        -- read result
        (data => "10010000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '0', dir => '0', ack=>'X', addr => "XXX"),
        (data => "10010001", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "XXXXXXXX", restart => '0', dir => '1', ack=>'0', addr => "100"),
        (data => "XXXXXXXX", restart => '0', dir => '1', ack=>'0', addr => "101"),

        -- write mux and trigger:
        (data => "10010000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000001", restart => '0', dir => '0', ack=>'X', addr => "XXX"),
        (data => "11110011", restart => '0', dir => '0', ack=>'X', addr => "XXX"),
        (data => "11100000", restart => '0', dir => '0', ack=>'X', addr => "XXX"),
        -- stall 
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        -- read result
        (data => "10010000", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "00000000", restart => '0', dir => '0', ack=>'X', addr => "XXX"),
        (data => "10010001", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        (data => "XXXXXXXX", restart => '0', dir => '1', ack=>'0', addr => "110"),
        (data => "XXXXXXXX", restart => '0', dir => '1', ack=>'0', addr => "111")
        )
      )
    port map (
      i_hk_fast_clk => i_hk_fast_clk,
      i_trigger     => r_trigger,
      i_spi_clk     => r_internal_clk,
      i_spi_mosi    => r_internal_mosi,
      o_spi_miso    => r_ads1015_miso,
      i_dev_select  => r_subsystem_select,
      io_hk_sda     => io_ads1015_sda,
      io_hk_scl     => io_ads1015_scl,
      o_latched     => r_ads1015_data
      );

  ns_led : status_led
    generic map (
      g_MIN_VOLTAGE => 550,
      g_MAX_VOLTAGE => 650
      )
    port map (
      i_clk  => i_hk_fast_clk,
      i_data => r_ads1015_data(31 downto 0),
      o_led  => o_led_ns
      );

  ew_led : status_led
    generic map (
      g_MIN_VOLTAGE => 550,
      g_MAX_VOLTAGE => 650
      )
    port map (
      i_clk  => i_hk_fast_clk,
      i_data => r_ads1015_data(63 downto 32),
      o_led  => o_led_ew
      );
      

  si7060_1 : i2c_wrapper
    generic map (
      g_SUBSYSTEM_ADDR => "00000101",
      --g_CLK_DIV => 500,
      g_SEQ_DATA => (
        -- write address:
        (data => "01100010", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        -- write register (0xC4 i.e. config register)
        (data => "11000100", restart => '0', dir => '0', ack=>'X', addr => "XXX"),
        -- write data to reg C4 (i.e. start a one-burst conversion)
        (data => "00000100", restart => '0', dir => '0', ack=>'X', addr => "XXX"),
        --
        -- write address:
        --(data => "01100010", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        -- write register (0xC0, i.e. chip id and rev):
        --(data => "11000000", restart => '0', dir => '0', ack=>'X', addr => "XXX"),
        -- restart and write address again:
        --(data => "01100011", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        -- read value of that reg, transmit NACK and save data at 000:
        --(data => "XXXXXXXX", restart => '0', dir => '1', ack=>'1', addr => "010"),
        --
        -- write address:
        (data => "01100010", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        -- write register (0xC1, i.e. high word of temp):
        (data => "11000001", restart => '0', dir => '0', ack=>'X', addr => "XXX"),
        -- restart and write address again:
        (data => "01100011", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        -- read value of that reg, transmit NACK and save data at 001:
        (data => "XXXXXXXX", restart => '0', dir => '1', ack=>'1', addr => "001"),
        --
        -- write address:
        (data => "01100010", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        -- write register (0xC2, i.e. low word of temp):
        (data => "11000010", restart => '0', dir => '0', ack=>'X', addr => "XXX"),
        -- restart and write address again:
        (data => "01100011", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        -- read value of that reg, transmit NACK and save data at 010:
        (data => "XXXXXXXX", restart => '0', dir => '1', ack=>'1', addr => "000")
        --
        -- write address:
        --(data => "01100010", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        -- write register (0xC4, i.e. config register):
        --(data => "11000100", restart => '0', dir => '0', ack=>'X', addr => "XXX"),
        -- restart and write address again:
        --(data => "01100011", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        -- read value of that reg, transmit NACK and save data at 011:
        --(data => "XXXXXXXX", restart => '0', dir => '1', ack=>'1', addr => "011"),
        --
        -- write address:
        --(data => "01100010", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        -- write register (0xC5, i.e. auto inc enable):
        --(data => "11000101", restart => '0', dir => '0', ack=>'X', addr => "XXX"),
        -- restart and write address again:
        --(data => "01100011", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        -- read value of that reg, transmit NACK and save data at 100:
        --(data => "XXXXXXXX", restart => '0', dir => '1', ack=>'1', addr => "100"),
        --
        -- write address:
        --(data => "01100010", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        -- write register (0xC9, i.e. sleep timer):
        --(data => "11001001", restart => '0', dir => '0', ack=>'X', addr => "XXX"),
        -- restart and write address again:
        --(data => "01100011", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
        -- read value of that reg, transmit NACK and save data at 101:
        --(data => "XXXXXXXX", restart => '0', dir => '1', ack=>'1', addr => "101")
        )
      )
    port map (
      i_hk_fast_clk => i_hk_fast_clk,
      i_trigger     => r_trigger,
      i_spi_clk     => r_internal_clk,
      i_spi_mosi    => r_internal_mosi,
      o_spi_miso    => r_si7060_miso,
      i_dev_select  => r_subsystem_select,
      io_hk_sda     => io_si7060_sda,
      io_hk_scl     => io_si7060_scl
      );


  -- fake trigger unit
  fake_trigger_1 : fake_trigger
    generic map (
      g_SUBSYSTEM_ADDR => "00000110"
      )
    port map (
      i_hk_fast_clk    => i_hk_fast_clk,
      i_spi_clk        => r_internal_clk,
      i_spi_mosi       => r_internal_mosi,
      o_spi_miso       => open,
      i_dev_select     => r_subsystem_select,
      o_trigger        => r_artificial_trigger
      );

  -- version info
  version_info_1 : version_info
    generic map (
      g_SUBSYSTEM_ADDR => "00000111",
      g_VERSION => std_logic_vector(to_unsigned(4, 8))
      )
    port map (
      i_hk_fast_clk => i_hk_fast_clk,
      i_spi_clk     => r_internal_clk,
      i_spi_mosi    => r_internal_mosi,
      o_spi_miso    => r_version_miso,
      i_dev_select  => r_subsystem_select
      );

  start_offset_register : spi_register
    generic map (
      g_SUBSYSTEM_ADDR => "00001000",
      g_REGISTER_WIDTH => 16
      )
    port map (
      i_hk_fast_clk => i_hk_fast_clk,
      i_spi_clk     => r_internal_clk,
      i_spi_mosi    => r_internal_mosi,
      o_spi_miso    => r_offset_miso,
      i_dev_select  => r_subsystem_select,
      o_value       => o_start_offset
      );
  
      
  spi_capture_1 : spi_capture
    generic map (
      g_SUBSYSTEM_ADDR => "00001011",
      g_DATA_WIDTH => g_DATA_WIDTH,
      g_BUFFER_LEN => 4096 )
    port map (
      i_spi_clk => r_internal_clk,
      i_spi_mosi => r_internal_mosi,
      o_spi_miso => r_capture_miso,
      i_dev_select => r_subsystem_select,
      -- channel A, first sample, MSB first
      i_data(51 downto 39)  => (
      51=>i_data(12), -- smuggled trigger bit
      50=>i_data(18),
      49=>i_data( 5),
      48=>i_data(17),
      47=>i_data( 4),
      46=>i_data(16),
      45=>i_data( 3),
      44=>i_data(15),
      43=>i_data( 2),
      42=>i_data(14),
      41=>i_data( 1),
      40=>i_data(13),
      39=>i_data( 0)     ),
    -- channel B, first sample, MSB first
    i_data(38 downto 26)  => (
      38=>i_data(25), -- smuggled trigger bit
      37=>i_data(24),
      36=>i_data(11),
      35=>i_data(23),
      34=>i_data(10),
      33=>i_data(22),
      32=>i_data( 9),
      31=>i_data(21),
      30=>i_data( 8),
      29=>i_data(20),
      28=>i_data( 7),
      27=>i_data(19),
      26=>i_data( 6)       ),
    -- channel A, second sample, MSB first
    i_data(25 downto 13)  => (
      25=>i_data(38), -- smuggled trigger bit
      24=>i_data(44),
      23=>i_data(31),
      22=>i_data(43),
      21=>i_data(30),
      20=>i_data(42),
      19=>i_data(29),
      18=>i_data(41),
      17=>i_data(28),
      16=>i_data(40),
      15=>i_data(27),
      14=>i_data(39),
      13=>i_data(26)      ),
    -- channel B, second sample, MSB first
    i_data(12 downto 0)  => (
      12=>i_data(51), -- smuggled trigger bit
      11=>i_data(50),
      10=>i_data(37),
      9 =>i_data(49),
      8 =>i_data(36),
      7 =>i_data(48),
      6 =>i_data(35),
      5 =>i_data(47),
      4 =>i_data(34),
      3 =>i_data(46),
      2 =>i_data(33),
      1 =>i_data(45),
      0 =>i_data(32)     ),
      i_data_clk => i_data_clk );
  
  
  -- instantiate gpio subsystem
  digitalout_1 : digitaloutput
    generic map (
      g_SUBSYSTEM_ADDR => "00000001"
      )
    port map (
      i_clk => i_hk_fast_clk,
      i_spi_clk => r_internal_clk,
      i_spi_mosi => r_internal_mosi,
      o_spi_miso => r_gpio_miso,
      i_dev_select => r_subsystem_select,
      o_data => o_gpio_data
      );  

  digitaloutput_bias : digitaloutput
    generic map (
      g_SUBSYSTEM_ADDR => "00001010",
      g_DEFAULT_OUTPUT => "11111111"
      )
    port map (
      i_clk => i_hk_fast_clk,
      i_spi_clk => r_internal_clk,
      i_spi_mosi => r_internal_mosi,
      o_spi_miso => r_bias_miso,
      i_dev_select => r_subsystem_select,
      o_data(0) => o_bias_ns,
      o_data(1) => o_bias_ew,
      o_data(7 downto 2) => open
      );
  
end behaviour;
  
