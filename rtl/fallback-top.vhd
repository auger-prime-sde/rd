--- AUGER radio extension FPGA toplevel design
--- Used in the fallback area of the flash
--- only provides minimal features: i.e. access to flash and version info only

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library ecp5u;
use ecp5u.components.all;


entity fallback_top is
  port (
    i_xtal_clk          : in std_logic;
    -- signals for eeprom
    i_hk_flash_miso     : in std_logic;
    o_hk_flash_mosi     : out std_logic;
    o_hk_flash_ce       : out std_logic;
    -- flash clk is routed out through a special USRMCLK block
    -- signals for housekeeping
    i_hk_uub_clk        : in std_logic;
    i_hk_uub_mosi       : in std_logic;
    i_hk_uub_ce         : in std_logic;
    o_hk_uub_miso       : out std_logic;
    -- TODO: put this as one of the gpio lines, for now this is tied high
    o_ns_bias_en        : out std_logic;
    o_ew_bias_en        : out std_logic;
    -- leds
    o_led_ns            : out std_logic;
    o_led_ew            : out std_logic
    );
end fallback_top;


architecture behaviour of fallback_top is
  

  
  -- wires for spi flash
  signal w_flash_clk : std_logic;
  signal w_flash_ce  : std_logic;
  signal r_flash_miso : std_logic;

  -- wires for version info block:
  signal r_version_miso : std_logic;

  -- wires between demux and other components:
  signal r_internal_clk : std_logic;
  signal r_internal_mosi : std_logic;

  -- subsystem address:
  signal r_subsystem_select : std_logic_vector(7 downto 0);

  signal r_hk_uub_clk, r_hk_uub_mosi, r_hk_uub_ce : std_logic;
  

  -- start of magic MCLK block
  -- (see ECP5 sysCONFIG manual section 6.1.2)
  component USRMCLK
    port(
      USRMCLKI : in std_ulogic;
      USRMCLKTS : in std_ulogic
      );
  end component;
  attribute syn_noprune: boolean ;
  attribute syn_noprune of USRMCLK: component is true;
  -- end of magic block

  
  component spi_demux is
    generic ( g_DEV_SELECT_BITS : natural := 8);
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



begin

  -- leds off
  o_led_ew <= '1';
  o_led_ns <= '1';

  -- bias off
  o_ns_bias_en <= '0';
  o_ew_bias_en <= '0';
  
  -- merge miso lines
  o_hk_uub_miso <= r_flash_miso or r_version_miso;

  -- connect ce line of flash chip to the correct housekeeping line
  o_hk_flash_ce <= w_flash_ce;

  process(i_xtal_clk) is
  begin
    if rising_edge(i_xtal_clk) then
      r_hk_uub_clk  <= i_hk_uub_clk;
      r_hk_uub_mosi <= i_hk_uub_mosi;
      r_hk_uub_ce   <= i_hk_uub_ce;
    end if;
  end process;
  
  spi_demux_1 : spi_demux
    generic map (g_DEV_SELECT_BITS => 8)
    port map (
      i_spi_clk     => r_hk_uub_clk,
      i_hk_fast_clk => i_xtal_clk,
      i_spi_mosi    => r_hk_uub_mosi,
      i_spi_ce      => r_hk_uub_ce,
      o_spi_clk     => r_internal_clk,
      o_spi_mosi    => r_internal_mosi,
      o_dev_select  => r_subsystem_select
      );


  
    
  u1: USRMCLK port map (
    USRMCLKI => w_flash_clk,
    USRMCLKTS => w_flash_ce);


  spi_wrapper_flash : spi_wrapper
    generic map (
      g_SUBSYSTEM_ADDR => "00000010"
      )
    port map (
      i_clk            => r_internal_clk,
      i_mosi           => r_internal_mosi,
      o_miso           => r_flash_miso,
      i_dev_select     => r_subsystem_select,
      o_clk            => w_flash_clk,
      o_mosi           => o_hk_flash_mosi,
      i_miso           => i_hk_flash_miso,
      o_ce             => w_flash_ce
      );


  -- version info
  version_info_1 : version_info
    generic map (
      g_SUBSYSTEM_ADDR => "00000111",
      g_VERSION => std_logic_vector(to_unsigned(16#FE#, 8))
      )
    port map (
      i_hk_fast_clk => i_xtal_clk,
      i_spi_clk     => r_internal_clk,
      i_spi_mosi    => r_internal_mosi,
      o_spi_miso    => r_version_miso,
      i_dev_select  => r_subsystem_select
      );

  
end;
