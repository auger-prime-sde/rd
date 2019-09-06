library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity digitaloutput is
  generic (
    g_SUBSYSTEM_ADDR : std_logic_vector;
	g_DEFAULT_OUTPUT : std_logic_vector (7 downto 0) := "11111111" 
    );
  port (
    i_clk : in std_logic;
    i_spi_clk : in std_logic;
    i_spi_mosi : in std_logic;
    o_spi_miso : out std_logic;
    i_dev_select : in std_logic_vector(g_SUBSYSTEM_ADDR'length-1 downto 0);
    o_data : out std_logic_vector (g_DEFAULT_OUTPUT'length-1 downto 0) := g_DEFAULT_OUTPUT
    );  
end  digitaloutput;

architecture Behavioral of digitaloutput is
  constant c_CMD_BITS : natural := 8;-- beware this cannot simply be changed due to wiring below
  signal r_ce         : std_logic;
  signal r_spi_miso   : std_logic;
  signal r_spi_data   : std_logic_vector(g_DEFAULT_OUTPUT'length-1 downto 0);
  signal r_spi_cmd    : std_logic_vector(c_CMD_BITS-1 downto 0);
  signal r_data       : std_logic_vector(g_DEFAULT_OUTPUT'length-1 downto 0) := g_DEFAULT_OUTPUT;
  signal r_recv_count : std_logic_vector(15 downto 0);
  signal r_valid      : std_logic;
  
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

  r_ce <= '0' when i_dev_select = g_SUBSYSTEM_ADDR else '1';
  o_spi_miso <= r_spi_miso when r_ce = '0' else '0';
  r_valid <= '1' when r_recv_count = std_logic_vector(to_unsigned(15, r_recv_count'length)) else '0';
  o_data <= r_data;

  
  process (i_Clk)
  begin
    if  rising_edge(i_clk) then
      if    (r_valid = '1' and unsigned(r_spi_cmd) = to_unsigned(0, c_CMD_BITS)) then -- just read. don't change anything
      elsif (r_valid = '1' and unsigned(r_spi_cmd) = to_unsigned(1, c_CMD_BITS)) then ---Write vector
        r_data <= r_spi_data;
      elsif (r_valid = '1' and unsigned(r_spi_cmd) = to_unsigned(2, c_CMD_BITS)) then --set bit
        r_data <= r_spi_data or  r_data;	
      elsif (r_valid = '1' and unsigned(r_spi_cmd) = to_unsigned(3, c_CMD_BITS)) then --reset bit
        r_data <= not r_spi_data and r_data ;	
      elsif (r_valid = '1' and unsigned(r_spi_cmd) = to_unsigned(4, c_CMD_BITS)) then --set to default
        r_data <= g_DEFAULT_OUTPUT;
      end if;
    end if;
  end process;


  spi_decoder_gpio : spi_decoder
    generic map (
      g_INPUT_BITS => 16,
      g_OUTPUT_BITS => 8
      )
    port map (
      i_spi_clk    => i_spi_clk,
      i_spi_mosi   => i_spi_mosi,
      o_spi_miso   => r_spi_miso,
      i_spi_ce     => r_ce,
      i_clk        => i_clk,
      o_data(g_DEFAULT_OUTPUT'length+c_CMD_BITS-1 downto g_DEFAULT_OUTPUT'length) => r_spi_cmd,
      o_data(g_DEFAULT_OUTPUT'length-1 downto 0) => r_spi_data,
      i_data       => r_data,
      o_recv_count => r_recv_count
      );


		
end Behavioral;
