library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity settable_counter is
  generic (
    g_SIZE : natural := 12
  );
  port (
    -- inputs
    i_en     : in std_logic;
    i_clk    : in std_logic;
    i_set    : in std_logic;
    i_data   : in std_logic_vector(g_SIZE-1 downto 0);

    -- output
    o_data   : out std_logic_vector(g_SIZE-1 downto 0)
    );
end settable_counter;


architecture behave of settable_counter is
  -- variables:
  signal r_counter : std_logic_vector(g_SIZE-1 downto 0) := (others => '1');
  --signal r_counter : natural range 0 to 4095; -- ouch, hardcoded 2^12-1  :,-(

  -- signatures of sub-components:
  -- none present
begin

  -- initialize sub-components here

  -- main program
  p_counter : process (i_clk) is
  begin
    if rising_edge(i_clk) then
      if i_set = '1' then
        r_counter <= i_data;
      else -- if i_set
        if i_en = '1' then
          r_counter <= std_logic_vector( unsigned(r_counter) + 1 );
        end if; -- if i_en = '1'
      end if; -- if i_set
    end if; -- rising edge(i_clk)
  o_data <= r_counter;
  end process;


end behave;
