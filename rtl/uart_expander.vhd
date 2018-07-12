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
	-- variables:
	signal r_Databuffer : std_logic_vector(g_WORDCOUNT*g_WORDSIZE-1 downto 0);
	signal r_Index : natural range 0 to g_WORDCOUNT-1;
	signal r_internal_dataready : std_logic := '0';
	signal r_internal_outputready : std_logic;
	signal r_internal_data : std_logic_vector(g_WORDSIZE-1 downto 0);

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


-- main program
	p_transmit : process (i_clk) is
	begin
		null;

	end process;

end behave;

