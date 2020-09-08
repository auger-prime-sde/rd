library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;


entity housekeeping is
  generic (
    g_DEV_SELECT_BITS : natural :=  8;
    --g_DATA_WIDTH : natural
    g_ADC_BITS : natural := 12
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
    i_data_ns_even      : in std_logic_vector(g_ADC_BITS-1 downto 0);
    i_data_ew_even      : in std_logic_vector(g_ADC_BITS-1 downto 0);
    i_data_ns_odd       : in std_logic_vector(g_ADC_BITS-1 downto 0);
    i_data_ew_odd       : in std_logic_vector(g_ADC_BITS-1 downto 0);
    i_data_extra        : in std_logic_vector(3 downto 0);
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
  signal r_capture_miso : std_logic := '0';
  
  -- internal wires for gpio:
  signal r_gpio_in      : std_logic_vector(15 downto 0);
  signal r_gpio_out     : std_logic_vector( 7 downto 0);
  signal r_gpio_count   : std_logic_vector(15 downto 0);
  signal r_gpio_trigger : std_logic;
  signal r_gpio_ce      : std_logic;
  signal r_gpio_miso    : std_logic;
  -- signals for bias dis/en-able
  signal r_bias_miso    : std_logic := '0';

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

  -- wires for calibration:
  signal r_calibration_miso : std_logic := '0';
  signal r_fft_clk : std_logic;


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
      g_SEQ_DATA : t_i2c_data;
      g_OUTPUT_WIDTH : natural;
      g_ACK : std_logic := '0'
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
      o_latched     : out std_logic_vector(2 ** g_OUTPUT_WIDTH * 8 - 1 downto 0)
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
      g_SUBSYSTEM_ADDR : std_logic_vector;
      g_CLK_POL : std_logic
      );
    port (
      i_hk_fast_clk : in std_logic;
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
      g_REGISTER_WIDTH : natural := 8;
      g_DEFAULT : std_logic_vector(g_REGISTER_WIDTH-1 downto 0) := (others => '0')
      );
    port (
      i_hk_fast_clk : in std_logic;
      i_spi_clk : in std_logic;
      i_spi_mosi : in std_logic;
      o_spi_miso : out std_logic;
      i_dev_select : in std_logic_vector(g_SUBSYSTEM_ADDR'length-1 downto 0);
      -- all bits can be individually overridden using the set/clear inputs
      i_set  : in std_logic_vector(g_REGISTER_WIDTH-1 downto 0); 
      i_clr  : in std_logic_vector(g_REGISTER_WIDTH-1 downto 0);
      o_data : out std_logic_vector(g_REGISTER_WIDTH-1 downto 0) := g_DEFAULT
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
             g_ADC_BITS: natural;
             g_BUFFER_ADDR_BITS: natural );
    port ( i_hk_clk   : in std_logic;
           i_spi_clk : in std_logic;
           i_spi_mosi : in std_logic;
           o_spi_miso : out std_logic;
           i_dev_select : in std_logic_vector(g_SUBSYSTEM_ADDR'length-1 downto 0);
           -- raw data
           i_data_ns_even : in std_logic_vector(g_ADC_BITS-1 downto 0);
           i_data_ew_even : in std_logic_vector(g_ADC_BITS-1 downto 0);
           i_data_ns_odd  : in std_logic_vector(g_ADC_BITS-1 downto 0);
           i_data_ew_odd  : in std_logic_vector(g_ADC_BITS-1 downto 0);
           i_data_extra   : in std_logic_vector(3 downto 0);
           i_data_clk : in std_logic);
  end component;

  component calibration is
    generic (
      g_CONTROL_SUBSYSTEM_ADDR : std_logic_vector;
      g_READOUT_SUBSYSTEM_ADDR : std_logic_vector;
      g_ADC_BITS : natural := 12;
      LOG2_FFT_LEN : integer := 10 );
    port (
      -- clk
      i_data_clk    : in std_logic;
      i_fft_clk     : in std_logic;
      i_hk_fast_clk : in std_logic;
      -- data input:
      i_data_ns_even : in std_logic_vector(g_ADC_BITS-1 downto 0);
      i_data_ns_odd  : in std_logic_vector(g_ADC_BITS-1 downto 0);
      i_data_ew_even : in std_logic_vector(g_ADC_BITS-1 downto 0);
      i_data_ew_odd  : in std_logic_vector(g_ADC_BITS-1 downto 0);
      -- spi interface for readout:
      i_spi_clk      : in std_logic;
      i_dev_select   : in std_logic_vector(g_CONTROL_SUBSYSTEM_ADDR'length-1 downto 0);
      i_spi_mosi     : in std_logic;
      o_spi_miso     : out std_logic );
  end component;
  
  constant c_ADS1015_READSEQUENCE : t_i2c_data := (
    -- write mux and trigger
    (data => "10010000", restart => '1', dir => '0', delay => '0'), -- addr+out
    (data => "00000001", restart => '0', dir => '0', delay => '0'), -- config register
    (data => "11000011", restart => '0', dir => '0', delay => '0'), -- set mux
    (data => "11100000", restart => '0', dir => '0', delay => '1'), -- trigger
    -- read result
    (data => "10010000", restart => '1', dir => '0', delay => '0'), -- addr+out
    (data => "00000000", restart => '0', dir => '0', delay => '0'), -- readout register
    (data => "10010001", restart => '1', dir => '0', delay => '0'), -- addr+in
    (data => "00000000", restart => '0', dir => '1', delay => '0'), -- write to 0x00
    (data => "00000001", restart => '0', dir => '1', delay => '0'), -- write to 0x01
    -- write mux and trigger
    (data => "10010000", restart => '1', dir => '0', delay => '0'), -- addr
    (data => "00000001", restart => '0', dir => '0', delay => '0'),
    (data => "11010011", restart => '0', dir => '0', delay => '0'),
    (data => "11100000", restart => '0', dir => '0', delay => '1'),
    -- read result
    (data => "10010000", restart => '1', dir => '0', delay => '0'), -- addr
    (data => "00000000", restart => '0', dir => '0', delay => '0'),
    (data => "10010001", restart => '1', dir => '0', delay => '0'),
    (data => "00000010", restart => '0', dir => '1', delay => '0'),
    (data => "00000011", restart => '0', dir => '1', delay => '0'),
    -- write mux and trigger:
    (data => "10010000", restart => '1', dir => '0', delay => '0'), -- addr
    (data => "00000001", restart => '0', dir => '0', delay => '0'),
    (data => "11100011", restart => '0', dir => '0', delay => '0'),
    (data => "11100000", restart => '0', dir => '0', delay => '1'),
    -- read result
    (data => "10010000", restart => '1', dir => '0', delay => '0'), -- addr
    (data => "00000000", restart => '0', dir => '0', delay => '0'),
    (data => "10010001", restart => '1', dir => '0', delay => '0'),
    (data => "00000100", restart => '0', dir => '1', delay => '0'),
    (data => "00000101", restart => '0', dir => '1', delay => '0'),
    -- write mux and trigger:
    (data => "10010000", restart => '1', dir => '0', delay => '0'), -- addr
    (data => "00000001", restart => '0', dir => '0', delay => '0'),
    (data => "11110011", restart => '0', dir => '0', delay => '0'),
    (data => "11100000", restart => '0', dir => '0', delay => '1'),
    -- read result
    (data => "10010000", restart => '1', dir => '0', delay => '0'), -- addr
    (data => "00000000", restart => '0', dir => '0', delay => '0'),
    (data => "10010001", restart => '1', dir => '0', delay => '0'),
    (data => "00000110", restart => '0', dir => '1', delay => '0'),
    (data => "00000111", restart => '0', dir => '1', delay => '0')
    );
    

  constant c_SI7060_READSEQUENCE : t_i2c_data := (
    -- write address:
    ( data => "01100010", restart => '1', dir => '0', delay => '0'),
    -- write register (0xC4 i.e. config register)
    ( data => "11000100", restart => '0', dir => '0', delay => '0'),
    -- write data to reg C4 (i.e. start a one-burst conversion)
    ( data => "00000100", restart => '0', dir => '0', delay => '0'),
    --
    -- write address:
    ( data => "01100010", restart => '1', dir => '0', delay => '0'),
    -- write register (0xC1, i.e. high word of temp):
    ( data => "11000001", restart => '0', dir => '0', delay => '0'),
    -- restart and write address again:
    ( data => "01100011", restart => '1', dir => '0', delay => '0'),
    -- read value of that reg, transmit NACK and save data at 001:
    ( data => "00000001", restart => '0', dir => '1', delay => '0'),
    --
    -- write address:
    ( data => "01100010", restart => '1', dir => '0', delay => '0'),
    -- write register (0xC2, i.e. low word of temp):
    ( data => "11000010", restart => '0', dir => '0', delay => '0'),
    -- restart and write address again:
    ( data => "01100011", restart => '1', dir => '0', delay => '0'),
    -- read value of that reg, transmit NACK and save data at 010:
    ( data => "00000000", restart => '0', dir => '1', delay => '0')
    );


   component dac is
    generic (
      g_SUBSYSTEM_ADDR : std_logic_vector;
      g_CLK_DIV : natural := 125
    );
    port (
      i_hk_fast_clk : in std_logic;
      i_dev_select : in std_logic_vector(g_SUBSYSTEM_ADDR'length-1 downto 0);
      -- spi port
      i_spi_clk : in std_logic;
      i_spi_mosi : in std_logic;
      o_spi_miso: out std_logic;
      -- i2c port:
      sda : inout std_logic;
      scl : inout std_logic
      );
  end component;
  
begin

  -- adc has inverted clock polarity
  r_adc_clk <= not r_internal_clk;

  -- select the housekeeping output miso depending on the selected peripheral 
  o_hk_uub_miso <= r_flash_miso or r_adc_miso or r_gpio_miso or r_ads1015_miso or r_si7060_miso or r_version_miso or r_offset_miso  or r_capture_miso or r_bias_miso or r_calibration_miso;

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
      g_SUBSYSTEM_ADDR => "00000010",
      g_CLK_POL => '1'
      )
    port map (
      i_hk_fast_clk    => i_hk_fast_clk,
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
      g_SUBSYSTEM_ADDR => "00000011",
      g_CLK_POL => '0'
      )
    port map (
      i_hk_fast_clk    => i_hk_fast_clk,
      i_clk            => r_internal_clk,
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
      g_MAX_COUNT => 5 -- from 100 MHz to 20 MHz
      )
    port map (
      i_clk => i_hk_fast_clk,
      o_clk => r_reveal_clk
      );

  clock_divider_fft : clock_divider
    generic map (
      g_MAX_COUNT => 5 -- from 100 MHz to 20 MHz
      )
    port map (
      i_clk => i_hk_fast_clk,
      o_clk => r_fft_clk
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
      g_SEQ_DATA => c_ADS1015_READSEQUENCE,
      g_OUTPUT_WIDTH => 3,
      g_ACK => '0'
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
      g_SEQ_DATA => c_SI7060_READSEQUENCE,
      g_OUTPUT_WIDTH => 1,
      g_ACK => '1' -- this chip has it's ack values inverted, see datasheet
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
      g_VERSION => std_logic_vector(to_unsigned(6, 8))
      )
    port map (
      i_hk_fast_clk => i_hk_fast_clk,
      i_spi_clk     => r_internal_clk,
      i_spi_mosi    => r_internal_mosi,
      o_spi_miso    => r_version_miso,
      i_dev_select  => r_subsystem_select
      );

  
  calibration_1 : calibration
    generic map (
      g_CONTROL_SUBSYSTEM_ADDR => "00001100",
      g_READOUT_SUBSYSTEM_ADDR => "00001101",
      g_ADC_BITS => 12,
      LOG2_FFT_LEN => 9 -- 1024 bins complex fft on 2048 reals.
      )
    port map (
      i_data_clk     => i_data_clk,
      i_fft_clk      => r_fft_clk,
      i_hk_fast_clk  => i_hk_fast_clk,
      i_data_ns_even => i_data_ns_even,--i_data(50 downto 39),
      i_data_ns_odd  => i_data_ns_odd, --i_data(24 downto 13),
      i_data_ew_even => i_data_ew_even,--i_data(37 downto 26),
      i_data_ew_odd  => i_data_ew_odd, --i_data(11 downto 0),
      i_spi_clk      => r_internal_clk,
      i_dev_select   => r_subsystem_select,
      i_spi_mosi     => r_internal_mosi,
      o_spi_miso     => r_calibration_miso
      );

        

  
  start_offset_register : spi_register
    generic map (
      g_SUBSYSTEM_ADDR => "00001000",
      g_REGISTER_WIDTH => 16,
      g_DEFAULT        => std_logic_vector(to_unsigned(1024, 16))
      )
    port map (
      i_hk_fast_clk => i_hk_fast_clk,
      i_spi_clk     => r_internal_clk,
      i_spi_mosi    => r_internal_mosi,
      o_spi_miso    => r_offset_miso,
      i_dev_select  => r_subsystem_select,
      i_set         => (others => '0'),
      i_clr         => (others => '0'),
      o_data        => o_start_offset
      );
  
      
--  spi_capture_1 : spi_capture
--    generic map (
--      g_SUBSYSTEM_ADDR => "00001011",
--      g_ADC_BITS => g_ADC_BITS,
--      g_BUFFER_ADDR_BITS => 10 ) -- 1024 / 2048 / 4096 / 8192 / 16384 -- note that
--                             -- this is the number of clock cycles before even
--                             -- and odd are split so you'll get twice as many samples
--    port map (
--      i_hk_clk => i_hk_fast_clk,
--      i_spi_clk => r_internal_clk,
--      i_spi_mosi => r_internal_mosi,
--      o_spi_miso => r_capture_miso,
--      i_dev_select => r_subsystem_select,
--      i_data_ns_even => i_data_ns_even,
--      i_data_ew_even => i_data_ew_even,
--      i_data_ns_odd  => i_data_ns_odd,
--      i_data_ew_odd  => i_data_ew_odd,
--      i_data_extra   => i_data_extra,
--      i_data_clk => i_data_clk );
  
  
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

  dac_1 : dac
    generic map (
      g_SUBSYSTEM_ADDR => "00001110"
      )
    port map (
      i_hk_fast_clk => i_hk_fast_clk,
      i_dev_select => r_subsystem_select,
      i_spi_clk    => r_internal_clk,
      i_spi_mosi   => r_internal_mosi,
      o_spi_miso   => open,
      sda => io_ads1015_sda,
      scl => io_ads1015_scl
      );
  
end behaviour;
  
