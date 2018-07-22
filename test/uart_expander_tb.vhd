library ieee;
use ieee.std_logic_1164.all;
use IEEE.Numeric_STD.all;

entity uart_expander_tb is
end uart_expander_tb;

architecture behavior of uart_expander_tb is
	constant clk_period : time := 10 ns;
	constant wordsize : integer := 7;
	constant wordcount : integer := 4;
	constant expecteddata : std_logic_vector(wordsize*wordcount-1 downto 0) := "0001100000110100011100001111";
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

		clk <= '1';
		wait for clk_period / 2;
		clk <= '0';
		wait for clk_period / 2;
	end process;

	p_test : process is
	begin
		-- initially the serializer should be ready
		assert o_ready = '1' report "Initial state of serializer was not ready";
		assert o_data = '1' report "Wrong logic level for idle serializer";

		-- test single packet, entered during clk low
		wait for 47 ns;
		-- I would like to get the 28 bit message:
		-- 0001100 0001101 0001110 0001111
		-- i.e. 0x0C 0x0D 0x0E 0x0F
		-- the 13 bits numbers that we therefore need are
		--          0011000001101
		-- 	 				and  0011100001111
		in_data <= "00110000011010011100001111";
		dataready <= '1';
		
		for wi in 0 to wordcount-1 loop
			wait for clk_period;
			assert o_data = '0' report "Start bit not received";
			for bi in 0 to wordsize -1 loop
				wait for clk_period;
				assert o_data = expecteddata(wi*wordsize + bi) report "Wrong data bit";
			end loop;
			wait for clk_period;
			assert o_data = '1' report "Stop bit not received";
		end loop;

		dataready <= '0';

		-- test signals between words
		assert o_data = '1' report "Data line low between transmissions";
		assert o_ready = '1' report "device not ready after transmission";
		
		wait for 145 ns;


		dataready <= '1';
		for wi in 0 to wordcount-1 loop
			wait for clk_period;
			assert o_data = '0' report "Start bit not received";
			for bi in 0 to wordsize -1 loop
				wait for clk_period;
				assert o_data = expecteddata(wi*wordsize + bi) report "Wrong data bit";
			end loop;
			if wi < wordcount-1 then -- skip the last stop bit check to set
									 -- next data
				wait for clk_period;
				assert o_data = '1' report "Stop bit not received";
			end if;
		end loop;

		-- last data bit has been verified.
		-- this is the time to set new data
		in_data <= "10100001010011010100101011";
		
		-- now proceed with checking the last stop bit from the previous message
		wait for clk_period;
		assert o_data = '1' report "Stop bit not received";

		-- just keep data-ready high such that transmission continues
		--dataready <= '0';


		for wi in 0 to wordcount-1 loop
			wait for clk_period;
			assert o_data = '0' report "Start bit not received";
			for bi in 0 to wordsize -1 loop
				wait for clk_period;
				--assert o_data = expecteddata(wi*wordsize + bi) report "Wrong data bit";
			end loop;
			wait for clk_period;
			assert o_data = '1' report "Stop bit not received";
		end loop;

		dataready <= '0';
		
		-- final wait
		wait for 100 ns;

		

		stop <= '1';
		wait;
	end process;

end behavior;
