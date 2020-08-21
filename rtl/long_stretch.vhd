library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity long_stretch is
  generic (
    g_BITS : natural := 16
    );
  port (
    i_clk  : in std_logic;
    i_data : in std_logic;
    o_data : out std_logic;
    i_length : in std_logic_vector(g_BITS-1 downto 0)
    );
end long_stretch;





architecture behave of long_stretch is
  signal r_count : natural range 0 to 2 ** g_BITS - 1 := 2 ** g_BITS - 1;

  
begin
  p_stretch : process (i_clk) is
  begin
    if rising_edge(i_clk) then
      if i_data = '1' then
        -- when triggered, rewind
        r_count <= 0;
        o_data <= '1';
      elsif r_count < to_integer(unsigned(i_length)) then
        -- when not triggered, count towards max
        r_count <= r_count + 1;
        o_data <= '1';
      else
        o_data <= '0';
        -- when at max, stay there
      end if;
    end if;
  end process;

  --o_data <= '1' when r_count < to_integer(unsigned(i_length)) else '0';
end behave;

    
    
