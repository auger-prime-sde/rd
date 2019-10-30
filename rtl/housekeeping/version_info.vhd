library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity version_info is
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
end version_info;


architecture behaviour of version_info is
  signal r_spi_miso : std_logic;
  signal r_spi_ce : std_logic;
  

  
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
  r_spi_ce <= '0' when i_dev_select = g_SUBSYSTEM_ADDR else '1';
  o_spi_miso <= not r_spi_ce and r_spi_miso;

  
  spi_decoder_1 : spi_decoder
    generic map (
      g_INPUT_BITS  => 8,
      g_OUTPUT_BITS => 8
      )
    port map (
      i_spi_clk    => i_spi_clk,
      i_spi_mosi   => i_spi_mosi,
      o_spi_miso   => r_spi_miso,
      i_spi_ce     => r_spi_ce,
      i_clk        => i_hk_fast_clk,
      o_data       => open,
      i_data       => g_VERSION,
      o_recv_count => open
      );

  
  
end architecture behaviour;

