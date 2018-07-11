library ieee;
use ieee.std_logic_1164.all;
use IEEE.Numeric_STD.all;

entity uart_tb is
end uart_tb;

architecture behavior of uart_tb is
	constant clk_period : time := 10 ns;
	constant wordsize : integer := 7;
	signal clk, dataready, o_data, o_ready : std_logic := '0';
	signal in_data : std_logic_vector(wordsize-1 downto 0) := (others => '0');
	signal stop : std_logic := '0';
	
	component uart is
		generic (g_WORDSIZE : natural);
		port(
			i_data      : in std_logic_vector(g_WORDSIZE-1 downto 0);
			i_dataready : in std_logic;
			i_clk       : in std_logic;
			-- outputs
			o_data      : out std_logic := '1';
			o_ready     : out std_logic := '1'
		);
	end component;

begin
-- DUT instantiation
	dut : uart
	generic map (g_WORDSIZE => wordsize)
	port map (
		i_data => in_data,
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
		in_data <= std_logic_vector(to_unsigned(42, wordsize));
		-- TODO: check should not do anything before dataready is toggled
		wait for 50 ns;
		dataready <= '1';
		wait for clk_period * 2;
		dataready <= '0';
		wait for 500 ns;
		stop <= '1';
		wait;
	end process;

end behavior;
