library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity housekeeping is
  generic (
    g_DEV_SELECT_BITS : natural := 2;
    g_CMD_BITS : natural := 3;
    g_ADDR_BITS : natural := 24;
    g_DATA_IN_BITS : natural := 8;
    g_DATA_OUT_BITS : natural := 16
    );
  port (
    i_clk            : in std_logic;
    -- signals to/from UUB
    i_spi_clk        : in std_logic;
    i_spi_mosi       : in std_logic;
    o_spi_miso       : out std_logic;
    i_spi_ce         : in std_logic;
    --signals to housekeeping sub-modules
    o_device_select  : out std_logic_vector(g_DEV_SELECT_BITS-1 downto 0);
    o_cmd            : out std_logic_vector(g_CMD_BITS-1 downto 0);
    o_data           : out std_logic_vector(g_DATA_OUT_BITS-1 downto 0);
    i_data           : in std_logic_vector(g_DATA_IN_BITS-1 downto 0)
    );

  end housekeeping;

architecture behaviour of housekeeping is
  -- signals definitions

begin
  
  -- main process
  p_main : process(i_clk) is
  begin
    
  end process;
  
end behaviour;
  
