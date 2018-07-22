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
		assert o_data = '1' report "Wrong logic level for idle serializer";

		-- test with one word, entered during clk high
		wait for 47 ns;
		in_data <= std_logic_vector(to_unsigned(42, wordsize));
		dataready <= '1';
		wait for clk_period;
		assert o_data = '0' report "Start bit not received";
		dataready <= '0';
		for I in 0 to wordsize-1 loop
			wait for clk_period;
			assert o_data = in_data(I) report "Wrong data bit";
		end loop;
		wait for clk_period;
		assert o_data = '1' report "Stop bit not received";
		assert o_ready = '1' report "uart not ready after transmission was finished";

		-- test signals between words
		wait for 45 ns;
		assert o_data = '1' report "Bad logic level between words";
		assert o_ready = '1' report "uart not ready between words";
		wait for 10 ns;

		-- test with one word, entered during clk low
		in_data <= std_logic_vector(to_unsigned(66, wordsize));
		dataready <= '1';
		wait for clk_period;
		assert o_data = '0' report "Start bit not received";
		dataready <= '0';
		for I in 0 to wordsize-1 loop
			wait for clk_period;
			assert o_data = in_data(I) report "Wrong data bit";
		end loop;
		wait for clk_period;
		assert o_data = '1' report "Stop bit not received";
		assert o_ready = '1' report "uart not ready after transmission was finished";

		-- test with 0x00 and 0x7F
		wait for 50 ns;
		in_data <= std_logic_vector(to_unsigned(0, wordsize));
		dataready <= '1';
		wait for clk_period;
		assert o_data = '0' report "Start bit not received";
		dataready <= '0';
		for I in 0 to wordsize-1 loop
			wait for clk_period;
			assert o_data = in_data(I) report "Wrong data bit";
		end loop;
		wait for clk_period;
		assert o_data = '1' report "Stop bit not received";
		assert o_ready = '1' report "uart not ready after transmission was finished";

		wait for 50 ns;
		in_data <= std_logic_vector(to_unsigned(127, wordsize));
		dataready <= '1';
		wait for clk_period;
		assert o_data = '0' report "Start bit not received";
		dataready <= '0';
		for I in 0 to wordsize-1 loop
			wait for clk_period;
			assert o_data = in_data(I) report "Wrong data bit";
		end loop;
		wait for clk_period;
		assert o_data = '1' report "Stop bit not received";
		assert o_ready = '1' report "uart not ready after transmission was finished";


		-- test with a ready signal that arrives right on the clock edge
		wait for 53 ns;
		in_data <= "1100110";
		dataready <= '1';
		wait for clk_period;
		assert o_data = '0' report "Start bit not received";
		dataready <= '0';
		for I in 0 to wordsize-1 loop
			wait for clk_period;
			assert o_data = in_data(I) report "Wrong data bit";
		end loop;
		wait for clk_period;
		assert o_data = '1' report "Stop bit not received";
		assert o_ready = '1' report "uart not ready after transmission was finished";
		wait for 2 ns;

		-- let's try some words back-to-back:
		wait for 40 ns;
		in_data <= std_logic_vector(to_unsigned(25, wordsize));
		dataready <= '1';
		wait for 2*clk_period; -- now in data
		dataready <= '0';
		wait for (wordsize-1)*clk_period; -- should now be in last data bit and
                                          -- ready for more data
		assert o_ready = '1' report "uart not ready in time for next data word";
		wait for clk_period; -- now inside stop bit
		assert o_data = '1' report "Stop bit not received";
		assert o_ready = '1' report "uart became unready during stop bit";
		in_data <= std_logic_vector(to_unsigned(26, wordsize));
		dataready <= '1';
		wait for clk_period; -- now inside start bit
		assert o_data = '0' report "Start bit not received";
		dataready <= '0';
		for I in 0 to wordsize-1 loop
			wait for clk_period;
			assert o_data = in_data(I) report "Wrong data bit";
		end loop;
		-- now we don't wait for stop-bit but immediately clock in the next data
		--wait for clk_period;
		assert o_ready = '1' report "uart not ready during last bit of previous word";
		in_data <= std_logic_vector(to_unsigned(27, wordsize));
		dataready <= '1';
		wait for 2*clk_period; -- now inside start bit
		dataready <= '0';
		assert o_data = '0' report "Start bit not received";
		for I in 0 to wordsize-2 loop -- we check one bit less because of
                                          -- the next test...
			wait for clk_period;
			assert o_data = in_data(I) report "Wrong data bit";
		end loop;
		-- let's try that one more time but now immediately send in the next
        -- word when o_ready becomes high
		wait until o_ready = '1';
		in_data <= std_logic_vector(to_unsigned(28, wordsize));
		dataready <= '1';
		wait for 1.5 * clk_period; -- now mid-stop bit again
		assert o_data = '1' report "stop bit not received";
		wait for clk_period;
		dataready <= '0';
		assert o_data = '0' report "start bit not received";
		for I in 0 to wordsize-1 loop
			wait for clk_period;
			assert o_data = in_data(I) report "Wrong data bit";
		end loop;
		wait for clk_period;
		assert o_data = '1' report "stop bit not received";



		
		wait for 10*clk_period;
		stop <= '1';
		wait;
	end process;

end behavior;
