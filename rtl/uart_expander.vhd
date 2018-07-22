library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_expander is
	generic (
		g_WORDSIZE : natural := 7;
		g_WORDCOUNT: natural := 4
	);
	port (
		-- inputs
		i_data      : in std_logic_vector(g_WORDCOUNT*g_WORDSIZE-1 downto 0);
		i_dataready : in std_logic;
		i_clk       : in std_logic;
		-- outputs
		o_data      : out std_logic := '1';
		o_ready     : out std_logic := '1'
	);
end uart_expander;


architecture behave of uart_expander is
	-- Variables:
	signal r_Index : natural range 0 to g_WORDCOUNT-1 := 0;
	signal r_internal_dataready : std_logic := '0';
	signal r_internal_outputready : std_logic;
	signal r_internal_data : std_logic_vector(g_WORDSIZE-1 downto 0) := (others=> '0');

	-- internal 7 bit uart
	component uart
		generic (
			g_WORDSIZE : natural
		);
		port (
			i_data : in std_logic_vector(g_WORDSIZE-1 downto 0);
			i_dataready : in std_logic;
			i_clk : in std_logic;
			o_data : out std_logic;
			o_ready : out std_logic
		);
	end component;

begin
	internal_uart : uart
		generic map (g_WORDSIZE => g_WORDSIZE)
		port map (
			i_data => r_internal_data,
			i_dataready => r_internal_dataready,
			i_clk => i_clk,
			o_data => o_data,
			o_ready => r_internal_outputready
		);


	-- whenever internal uart outputready flag goes up, we increment the index
	p_wordcount : process (r_internal_outputready) is
	begin
		if rising_edge (r_internal_outputready) then
			r_Index <= (r_Index + 1) mod g_wordcount;
		end if;
	end process;
	

	-- the following qualifies as a "hack". By setting dataready '1'
	-- when index!=0 it is ensured that the internal uart sees it high
	-- for all bytes that are not the first. By adding a '1' also when
	-- i_dataready is '1' it is also seen high for the first byte. It
	-- toggles low for a while inbetween but the interface of the
	-- internal uart is such that this does not matter.	
	r_internal_dataready <= '1' when i_dataready='1' or (r_Index /= 0) else '0';

	-- data fed to the internal uart is just a portion of the larger data muxed
	-- with the index
	r_internal_data(g_WORDSIZE-1 downto 0) <= i_data((r_Index+1)*g_WORDSIZE-1 downto r_Index*g_WORDSIZE);

	-- this aggregate uart is busy as long as the internal uart is busy. The
	-- extra condition on the index keeps the output ready low in the short
	-- intervals between internal words
	o_ready <= '0' when (r_internal_outputready='0') or (r_Index /= 0) else '1';

end behave;

