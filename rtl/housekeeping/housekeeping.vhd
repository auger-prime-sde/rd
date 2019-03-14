library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity housekeeping is
  generic ( g_DEV_SELECT_BITS : natural :=  32 );
  port (
    i_clk            : in std_logic; -- 50 MHz for internal operations
    -- signals to/from UUB
    i_spi_clk        : in std_logic;
    i_spi_mosi       : in std_logic;
    o_spi_miso       : out std_logic;
    i_spi_ce         : in std_logic  );

end housekeeping;


architecture behaviour of housekeeping is
  -- define lines for sub-system selection:
  constant c_NUM_SUBSYTEMS : natural := 6;
  signal r_subsystem_select   : std_logic_vector(g_DEV_SELECT_BITS-1 downto 0);
  signal r_subsystem_ce_lines : std_logic_vector(c_NUM_SUBSYTEMS downto 1);

  -- define lines for gpio:
  signal r_gpio_in    : std_logic_vector(31 downto 0);
  signal r_gpio_out   : std_logic_vector(31 downto 0);
  signal r_gpio_count : std_logic_vector(31 downto 0);
  
  component spi_demux is
    generic ( g_DEV_SELECT_BITS : natural := g_DEV_SELECT_BITS );
    port (
      i_spi_clk    : in  std_logic;
      i_spi_mosi   : in  std_logic;
      o_spi_miso   : out std_logic;
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

begin

  -- code for subsystem select address to one-hot:
  g_GENERATE_FOR: for s in 1 to c_NUM_SUBSYTEMS generate
    r_subsystem_ce_lines(s) <= '1' when to_integer(unsigned(r_subsystem_select)) = s else '0';
  end generate;

  
  -- instantiate one spi demuxer
  spi_demux_1 : spi_demux
    generic map (g_DEV_SELECT_BITS => g_DEV_SELECT_BITS)
    port map (
      i_spi_clk    => i_spi_clk,
      i_spi_mosi   => i_spi_mosi,
      o_spi_miso   => o_spi_miso,
      i_spi_ce     => i_spi_ce,
      o_dev_select => r_subsystem_select
      );


  -- instantiate one spi_decoder and one gpio subsystem
  spi_decoder_gpio : spi_decoder
    port map (
      i_spi_clk    => i_spi_clk,
      i_spi_mosi   => i_spi_mosi,
      o_spi_miso   => o_spi_miso,
      i_spi_ce     => r_subsystem_ce_lines(1),
      i_clk        => i_clk,
      o_data       => r_gpio_in,
      i_data       => r_gpio_out
      );
  -- gpio_1 : gpio
  --   port map (
  --     i_cmd               => r_gpio_in(31 downto 28),
  --     i_addr              => r_gpio_in(27 downto 20),
  --     i_data              => r_gpio_in(19 downto 12),
  --     o_data( 7 downto 0) => r_gpio_out,
  --     o_data(31 downto 8) => (others => '0'),
  --     i_enable            => r_subsystem_ce_lines(1),
  --     i_recv_count        => r_gpio_count );
      
  
  
  
end behaviour;
  
