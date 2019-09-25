library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity fake_trigger is
  generic (
    g_SUBSYSTEM_ADDR : std_logic_vector
    );
  port (
    i_hk_fast_clk : in std_logic;
    i_spi_clk     : in std_logic;
    i_spi_mosi    : in std_logic;
    o_spi_miso    : out std_logic;
    i_dev_select  : in std_logic_vector(g_SUBSYSTEM_ADDR'length-1 downto 0);
    o_trigger     : out std_logic
    );
end fake_trigger;


architecture behave of fake_trigger is
begin

  o_trigger <= '1' when i_dev_select = g_SUBSYSTEM_ADDR else '0';

end behave;

    
