library ieee;
use ieee.std_logic_1164.all;

entity spi_register_tb is
end spi_register_tb;


architecture behave of spi_register_tb is

  ----------------------------------
  -- Constants
  ----------------------------------
  constant clk_period_hk   : time :=  10 ns; -- 100 MHz
  constant clk_period_spi  : time := 200 ns; --   5 MHz

  ---------------------------------
  -- Sub component declarations
  ---------------------------------
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
      i_set  : in std_logic_vector(g_REGISTER_WIDTH-1 downto 0);
      i_clr  : in std_logic_vector(g_REGISTER_WIDTH-1 downto 0);
      o_data : out std_logic_vector(g_REGISTER_WIDTH-1 downto 0)
      );
  end component;

  --------------------------------
  -- Signals
  --------------------------------
  -- for simulation
  signal hk_clk : std_logic := '1';
  signal stop : std_logic := '0';

  -- data
  signal set, clr, data : std_logic_vector(7 downto 0) := (others => '0');
  
  -- spi port
  signal dev_select : std_logic_vector(7 downto 0) := "00000000";
  signal miso, mosi, spi_clk : std_logic := '1';
    

  ---------------------------------
  -- Test patterns
  ---------------------------------
  type t_testpattern is array (0 to 3) of bit_vector(7 downto 0);
  constant test_patterns : t_testpattern :=
    (B"10101010",
     B"01010101",
     B"01100110",
     B"11100011" );

  
begin

  --------------------------------
  -- dut instantiation
  --------------------------------
  dut : spi_register
    generic map (
      g_SUBSYSTEM_ADDR => "00000001",
      g_REGISTER_WIDTH => 8,
      g_DEFAULT        => "00001111"
      )
    port map (
      i_hk_fast_clk => hk_clk,
      i_spi_clk     => spi_clk,
      i_spi_mosi    => mosi,
      o_spi_miso    => miso,
      i_dev_select  => dev_select,
      i_set         => set,
      i_clr         => clr,
      o_data        => data);

  ---------------------------------
  -- clock generator
  ---------------------------------

  p_hk_clk : process is
  begin
    if stop = '1' then
      wait;
    else
      hk_clk <= not hk_clk;
      wait for clk_period_hk / 2;
    end if;
  end process;


  ---------------------------------
  -- SPI transaction simulation
  ---------------------------------
  p_main : process is
  begin

    -- initial delay
    wait for 100 * clk_period_hk;

    -- first test without set/clr
    
    -- spi transaction
    dev_select <= "00000001";
    wait for clk_period_spi / 2;
    for i in 7 downto 0 loop
      spi_clk <= '0';
      mosi <= to_stdulogic(test_patterns(0)(i));
      wait for clk_period_spi / 2;
      spi_clk <= '1';
      wait for clk_period_spi / 2;
    end loop;
    dev_select <= (others => '0');
    wait for 2 * clk_period_hk;
    assert data = to_stdlogicvector(test_patterns(0)) report "spi decode error";

    -- now forcibly set and clear some bits
    wait for clk_period_spi;
    set <= "11100000";
    clr <= "00000111";
    --wait for clk_period_spi;
    --set <= "00000000";
    --clr <= "00000000";
    
    
    -- spi transaction
    dev_select <= "00000001";
    wait for clk_period_spi / 2;
    for i in 7 downto 0 loop
      spi_clk <= '0';
      mosi <= to_stdulogic(test_patterns(1)(i));
      wait for clk_period_spi / 2;
      spi_clk <= '1';
      wait for clk_period_spi / 2;
    end loop;
    dev_select <= (others => '0');
    wait for 2 * clk_period_hk;
    assert data = ((to_stdlogicvector(test_patterns(1)) or set) and (not clr)) report "spi decode error";

    
    -- final delay
    wait for 100 * clk_period_hk;
    
    
    stop <= '1';
    wait;
  end process;
  
  
end behave;

