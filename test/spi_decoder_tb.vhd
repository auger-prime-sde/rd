library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

entity spi_decoder_tb is
end spi_decoder_tb;

architecture behave of spi_decoder_tb is
  constant clk_period : time := 20.2 ns; -- 50.0 MHz
  constant spi_period : time := 80 ns; -- 12.5 MHz

  constant c_WORDSIZE : natural := 8 ;
  constant c_INPUT_BITS : natural := 8;
  constant c_OUTPUT_BITS : natural := 8;

  signal stop : std_logic := '0';
  
  signal i_spi_clk    : std_logic := '1';
  signal i_spi_mosi   : std_logic := 'X';
  signal o_spi_miso   : std_logic := 'X';
  signal i_spi_ce     : std_logic := '1';
  signal i_clk        : std_logic := '1';
  signal o_data       : std_logic_vector(c_INPUT_BITS-1 downto 0);
  signal i_data       : std_logic_vector(c_OUTPUT_BITS-1 downto 0);
  signal o_recv_count : std_logic_vector(c_INPUT_BITS-1 downto 0);

  type t_testpattern is array (0 to 3) of bit_vector(c_INPUT_BITS-1 downto 0);
  constant test_patterns : t_testpattern :=
    (B"10101010",
     B"01010101",
     B"01100110",
     B"11100011" );

  component spi_decoder is
    generic (
      g_INPUT_BITS  : natural := c_INPUT_BITS;
      g_OUTPUT_BITS : natural := c_OUTPUT_BITS );
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

  dut : spi_decoder
    port map (
      i_spi_clk    => i_spi_clk,
      i_spi_mosi   => i_spi_mosi,
      o_spi_miso   => o_spi_miso,
      i_spi_ce     => i_spi_ce,
      i_clk        => i_clk,
      o_data       => o_data,
      i_data       => i_data,
      o_recv_count => o_recv_count );

  p_clk : process is
  begin
    -- Finish simulation when stop is asserted
    if stop = '1' then
      wait;
    end if;
    i_clk <= '0';
    wait for clk_period / 2;
    i_clk <= '1';
    wait for clk_period / 2;
  end process;

  p_test : process is
  begin
    wait for 146 ns;

    -- simulate an incomming spi packet with input data only
    i_spi_ce <= '0';
    wait for spi_period / 2; -- this timing corresponds to the output of the spi_demux
    for i in c_INPUT_BITS-1 downto 0 loop
      i_spi_clk <= '0';
      i_spi_mosi <= to_stdulogic(test_patterns(0)(i)); -- bits written on falling edges
      wait for spi_period / 2;
      i_spi_clk <= '1';
      wait for spi_period / 2;
    end loop;
    i_spi_ce <= '1';
    assert o_data = to_stdlogicvector(test_patterns(0)(c_INPUT_BITS-1  downto 0)) report "mosi decode error";

    wait for 200 ns;

    -- simulate an incomming spi packet with input data and output data
    i_spi_ce <= '0';
    wait for spi_period / 2; -- this timing corresponds to the output of the spi_demux
    for i in c_INPUT_BITS-1 downto 0 loop
      i_spi_clk <= '0';
      i_spi_mosi <= to_stdulogic(test_patterns(1)(i)); -- bits written on falling edges
      wait for spi_period / 2;
      i_spi_clk <= '1';
      if o_recv_count = std_logic_vector(to_unsigned(7, o_recv_count'length)) then
        i_data <= to_stdlogicvector(test_patterns(2));
      end if;
      wait for spi_period / 2;
    end loop;
    assert o_data = to_stdlogicvector(test_patterns(1)(c_INPUT_BITS-1  downto 0)) report "mosi decode error";
    for i in c_OUTPUT_BITS-1 downto 0 loop
      i_spi_clk <= '0';
      -- assert ??
      wait for spi_period / 2;
      i_spi_clk <= '1';
      wait for spi_period / 2;
    end loop;

    
    i_spi_ce <= '1';
    

    wait for 200 ns;


    
    
    stop <= '1';
    wait;
  end process;
  
  

end behave;

      
  
  
