library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity spi_register is
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
end spi_register;




architecture behave of spi_register is
  signal r_data : std_logic_vector(g_REGISTER_WIDTH-1 downto 0);
  signal w_data : std_logic_vector(g_REGISTER_WIDTH-1 downto 0);
  signal r_recv_count : std_logic_vector(g_REGISTER_WIDTH-1 downto 0);
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
  -- create ce line
  r_spi_ce <= '0' when i_dev_select = g_SUBSYSTEM_ADDR else '1';
  -- gate miso on ce line for good measure
  o_spi_miso <= not r_spi_ce and r_spi_miso;
  -- assign  output
  o_value <= w_data;
  
  spi_decoder_1 : spi_decoder
    generic map (
      g_INPUT_BITS => g_REGISTER_WIDTH,
      g_OUTPUT_BITS => g_REGISTER_WIDTH
      )
    port map (
      i_spi_clk => i_spi_clk,
      i_spi_mosi => i_spi_mosi,
      o_spi_miso => r_spi_miso,
      i_spi_ce => r_spi_ce,
      i_clk => i_hk_fast_clk,
      o_data => w_data,
      i_data => r_data,
      o_recv_count => r_recv_count
      );

  process(i_hk_fast_clk) is
  begin
    if rising_edge(i_hk_fast_clk) then
      if r_recv_count = std_logic_vector(to_unsigned(0, r_recv_count'length)) then
        r_data <= w_data;
      end if;
    end if;
  end process;
  
   
end behave;


