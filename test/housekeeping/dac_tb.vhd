library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

entity dac_tb is
end dac_tb;

architecture behave of dac_tb is
  constant clk_period : time :=   10 ns; -- 100.0 MHz
  constant spi_period : time := 1000 ns; --   1.0 MHz


  signal stop : std_logic := '0';
  signal clk : std_logic := '0';

  
  signal i_spi_clk    : std_logic := '1';
  signal i_spi_mosi   : std_logic := 'X';
  signal o_spi_miso   : std_logic := 'X';
  signal i_clk        : std_logic := '1';
  signal dev : std_logic_vector(7 downto 0) := "00000000";

  signal sda, scl : std_logic;

  constant test_patterns : bit_vector(31 downto 0) := B"11000000_00000000_01100110_11100011";

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

  dut : dac
    generic map (
      g_SUBSYSTEM_ADDR => "11001100"
      )
    port map (
      i_hk_fast_clk => clk,
      i_dev_select => dev,
      i_spi_clk    => i_spi_clk,
      i_spi_mosi   => i_spi_mosi,
      o_spi_miso   => o_spi_miso,
      sda => sda,
      scl => scl
      );

  p_clk : process is
  begin
    -- Finish simulation when stop is asserted
    if stop = '1' then
      wait;
    end if;
    clk <= not clk;
    wait for clk_period / 2;
  end process;

  p_test : process is
  begin
    wait for 146 ns;

    -- simulate an incomming spi packet with input data only
    dev <= "11001100";
    wait for spi_period / 2; -- this timing corresponds to the output of the spi_demux
    for i in 31 downto 0 loop
      i_spi_clk <= '0';
      i_spi_mosi <= to_stdulogic(test_patterns(i)); -- bits written on falling edges
      wait for spi_period / 2;
      i_spi_clk <= '1';
      wait for spi_period / 2;
    end loop;
    dev <= "00000000";
    --assert o_data = to_stdlogicvector(test_patterns(0)(c_INPUT_BITS-1  downto 0)) report "mosi decode error";

    wait for 200 us;
   
    
    stop <= '1';
    wait;
  end process;
  
  

end behave;
