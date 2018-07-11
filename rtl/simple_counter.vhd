--- Index counter module, keep track of current write index for the memory

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity simple_counter is
    generic (g_SIZE : natural := 11);
    port (
        i_clk: in  std_logic;
        o_q: out  std_logic_vector(g_SIZE-1 downto 0));
end simple_counter;

architecture behavior of simple_counter is
	constant maxCount : integer := 2**g_SIZE-1;

	signal r_count : integer range 0 to maxCount-1;

begin
	process(i_clk, r_count)
	begin
		if rising_edge(i_clk) then
			if r_count < maxCount then
				r_count <= r_count + 1;
			else
				r_count <= 0;
			end if;
		end if;
	end process;

	o_q <= std_logic_vector(to_unsigned(r_count, o_q'length));
end;
