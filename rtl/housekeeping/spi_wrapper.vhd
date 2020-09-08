library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity spi_wrapper is
  generic (
    g_SUBSYSTEM_ADDR : std_logic_vector;
    g_CLK_POL : std_logic
    );
  port (
    i_hk_fast_clk : in std_logic;
    -- interface in the direction of the uub
    i_clk        : in std_logic;
    i_mosi       : in std_logic;
    o_miso       : out std_logic;
    i_dev_select : in std_logic_vector(g_SUBSYSTEM_ADDR'length-1 downto 0);
    -- interface in the direction of the spi device
    o_clk        : out std_logic;
    o_mosi       : out std_logic;
    i_miso       : in std_logic;
    o_ce         : out std_logic
    );
end spi_wrapper;

architecture behaviour of spi_wrapper is
  constant DELAY : natural := 3 ;-- 3 * 10 ns > 25 ns setup and hold time requirement
  signal r_ce, r_delayed_clk : std_logic;

  component sync_1bit is
    generic ( g_NUM_STAGES : natural := 3 );
    port (
      i_clk : in std_logic;
      i_data :in  std_logic;
      o_data : out std_logic
      );
  end component;
begin

  delay_line : sync_1bit
    generic map (
      g_NUM_STAGES => DELAY
      )
    port map (
      i_clk => i_hk_fast_clk,
      i_data => i_clk,
      o_data => r_delayed_clk
      );


  g_if : if g_CLK_POL = '0' generate
    o_clk  <= r_delayed_clk when r_ce = '0' else '0';
  end generate;
  g_else : if g_CLK_POL = '1' generate
    o_clk  <= i_clk when r_ce = '0' else '1';
  end generate;

  
  
  r_ce   <= '0' when i_dev_select = g_SUBSYSTEM_ADDR else '1';
  o_ce   <= r_ce;
  o_mosi <= i_mosi when r_ce = '0' else '0';
  o_miso <= i_miso when r_ce = '0' else '0';
  
end behaviour;

