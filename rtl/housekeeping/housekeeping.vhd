library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity housekeeping is
  generic ( g_DEV_SELECT_BITS : natural :=  32 );
  port (
    i_clk            : in std_logic; -- 50 MHz for internal operations
    -- signals to/from UUB:
    i_spi_clk        : in std_logic;
    i_spi_mosi       : in std_logic;
    o_spi_miso       : out std_logic;
    i_spi_ce         : in std_logic;
    -- pins to/from subsystems:
    -- digitalout:
    o_digitalout     : out std_logic_vector(7 downto 0);
    -- flash:
    o_flash_ce       : out std_logic
    );

  

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
  signal r_gpio_trigger : std_logic;


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
      o_DataOut : out std_logic_vector (g_DATA_OUT_BITS-1 downto 0) := g_DEFAULT_OUTPUT; 
      o_busy	  : out std_logic
      );
  end component;
begin

  -- code for subsystem select address to one-low:
  g_GENERATE_FOR: for s in 1 to c_NUM_SUBSYTEMS generate
    r_subsystem_ce_lines(s) <= '0' when to_integer(unsigned(r_subsystem_select)) = s else '1';
  end generate;

  r_gpio_trigger <= '1' when r_gpio_count = std_logic_vector(to_unsigned(31, 32)) else '0';
  o_digitalout <= r_gpio_out(7 downto 0);

  o_flash_ce <= r_subsystem_ce_lines(2);
  
  -- instantiate one spi demuxer
  spi_demux_1 : spi_demux
    generic map (g_DEV_SELECT_BITS => g_DEV_SELECT_BITS)
    port map (
      i_spi_clk    => i_spi_clk,
      i_sample_clk => i_clk,
      i_spi_mosi   => i_spi_mosi,
      --o_spi_miso   => o_spi_miso,
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
      i_data       => r_gpio_out,
      o_recv_count => r_gpio_count
      );
   digitalout_1 : Digitaloutput
     port map (
       i_clk         => i_clk,
       i_enable      => r_gpio_trigger,
       i_cmd         => r_gpio_in(31 downto 24),
       i_data        => r_gpio_in(23 downto 16),
       o_dataout     => r_gpio_out(7 downto 0)
       );
      
  
  
  
end behaviour;
  
