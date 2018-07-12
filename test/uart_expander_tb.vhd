library ieee;
use ieee.std_logic_1164.all;
use IEEE.Numeric_STD.all;

entity uart_expander_tb is
end uart_expander_tb;

architecture behavior of uart_expander_tb is
	constant clk_period : time := 10 ns;
	constant wordsize : integer := 7;
	constant wordcount : integer := 4;
	signal clk, dataready, o_data, o_ready : std_logic := '0';
	signal in_data : std_logic_vector(25 downto 0) := (others => '0');
	signal stop : std_logic := '0';

	component uart_expander is
		generic (g_WORDSIZE : natural; g_WORDCOUNT : natural);
		port(
			i_data      : in std_logic_vector(g_WORDSIZE*g_WORDCOUNT-1 downto 0);
			i_dataready : in std_logic;
			i_clk       : in std_logic;
			-- outputs
			o_data      : out std_logic := '1';
			o_ready     : out std_logic := '1'
		);
	end component;

begin
-- DUT instantiation
	dut : uart_expander
	generic map (g_WORDSIZE => wordsize, g_WORDCOUNT => wordcount)
	port map (
		i_data(26 downto 14) => in_data(25 downto 13),
		i_data(12 downto 0) => in_data(12 downto 0),
		-- 13 and 27 are not assigned
		i_data(13) => '0',
		i_data(27) => '0',
		i_dataready => dataready,
		i_clk => clk,
		o_data => o_data,
		o_ready => o_ready
	);

	p_clk : process is
	begin
		-- Finish simulation when stop is asserted
		if stop = '1' then
			wait;
		end if;

		clk <= '0';
		wait for clk_period / 2;
		clk <= '1';
		wait for clk_period / 2;
	end process;

	p_test : process is
	begin
		-- initially the serializer should be ready
		assert o_ready = '1' report "Initial state of serializer was not ready";
		assert o_data = '1' report "Wrong logic level for idle serializer";

		-- TODO: make some actual tests
		report "Warning: no tests defined yet";

		stop <= '1';
		wait;
	end process;

end behavior;
