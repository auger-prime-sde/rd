library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

entity spi_demux_tb is
end spi_demux_tb;

architecture behave of spi_demux_tb is
  constant clk_period : time := 100 ns; -- 10 MHz housekeeping clk
  constant hk_clk_period : time := 10 ns; -- 100 MHz more than twice as fast

  signal stop : std_logic := '0';
  signal i_spi_clk  : std_logic := '1';
  signal i_hk_fast_clk : std_logic;
  signal i_spi_mosi : std_logic;
  signal o_spi_mosi : std_logic;
  signal i_spi_ce   : std_logic := '1';

  signal o_dev_select: std_logic_vector(7 downto 0);

  -- test pattern containing 8 dev bits and 24 data bits that should be forwarded
  type t_testpattern is array (0 to 2) of bit_vector(8+24-1 downto 0);
  constant test_patterns : t_testpattern :=
    (B"00000110_110011001100110011001100",
     B"00001100_110011001100110011001100",
     B"00000001_110011001100110011001100" );

  component spi_demux is
    generic (
      -- how many device select bits to 'cut' from the start of each transaction
      g_DEV_SELECT_BITS : natural := 8
      );
    port (
      i_spi_clk     : in  std_logic;
      i_hk_fast_clk : in  std_logic;
      i_spi_mosi    : in  std_logic;
      i_spi_ce      : in  std_logic;
      o_spi_clk     : out std_logic;
      o_spi_mosi    : out std_logic;
      o_dev_select  : out std_logic_vector(g_DEV_SELECT_BITS-1 downto 0) := (others => '0')
      );
  end component;

begin

  dut : spi_demux
    port map (
      i_spi_clk    => i_spi_clk,
      i_hk_fast_clk => i_hk_fast_clk,
      i_spi_mosi   => i_spi_mosi,
      i_spi_ce     => i_spi_ce,
      o_spi_clk    => open,
      o_spi_mosi   => o_spi_mosi,
      o_dev_select => o_dev_select
      );

  p_hk_clk : process is
  begin
    if stop = '1' then
      wait;
    end if;
    wait for hk_clk_period / 2;
    i_hk_fast_clk <= '0';
    wait for hk_clk_period / 2;
    i_hk_fast_clk <= '1';
  end process;
  
  
  p_test : process is
  begin
    wait for 115 ns;
    assert o_dev_select = (o_dev_select'range => '0') report "dev select should be all zero before first transaction";

    for t in 0 to 2 loop
      -- start transaction:
      i_spi_ce <= '0';
      wait for clk_period; -- amount should not matter

      for i in 0 to 31 loop
        i_spi_clk <= '0';
        i_spi_mosi <= to_stdulogic(test_patterns(t)(31 - i));
        wait for clk_period / 2;
        i_spi_clk <= '1';
        wait for clk_period / 2;
      end loop;
      assert o_dev_select = to_stdlogicvector(test_patterns(t)(31 downto 24)) report "device select decode failed";
      i_spi_ce <= '1';

      wait for 10 * clk_period;
    end loop;

    -- test what happens when a transaction is aborted:
    i_spi_ce <= '0';
    wait for clk_period; -- amount should not matter
    for i in 0 to 5 loop
      i_spi_clk <= '0';
      i_spi_mosi <= to_stdulogic(test_patterns(0)(31 - i));
      wait for clk_period / 2;
      i_spi_clk <= '1';
      wait for clk_period / 2;
    end loop;
    i_spi_ce <= '1';
    
    wait for 10 * clk_period;

    i_spi_ce <= '0';
    wait for clk_period;
    for i in 0 to 31 loop
        i_spi_clk <= '0';
        i_spi_mosi <= to_stdulogic(test_patterns(0)(31 - i));
        wait for clk_period / 2;
        i_spi_clk <= '1';
        wait for clk_period / 2;
      end loop;
      assert o_dev_select = to_stdlogicvector(test_patterns(0)(31 downto 24)) report "device select decode failed";
    i_spi_ce <= '1';

    
    wait for 10 * clk_period;
    
    stop <= '1';
    wait;
    
  end process;
  
  
end behave;

