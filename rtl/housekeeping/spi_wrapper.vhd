library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity spi_wrapper is
  generic (
    g_SUBSYSTEM_ADDR : std_logic_vector
    );
  port (
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
  signal r_ce : std_logic;
begin
  r_ce   <= '0' when i_dev_select = g_SUBSYSTEM_ADDR else '1';
  o_ce   <= r_ce;
  o_clk  <= i_clk when r_ce = '0' else '0';
  o_mosi <= i_mosi when r_ce = '0' else '0';
  o_miso <= i_miso when r_ce = '0' else '0';
  
end behaviour;

