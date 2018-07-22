library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- I believe that technically this is called a usart, not a uart
entity uart is
	generic (
		g_WORDSIZE : natural := 7
	);
	port (
		-- inputs
		i_data      : in std_logic_vector(g_WORDSIZE-1 downto 0);
		i_dataready : in std_logic;
		i_clk       : in std_logic;
		-- outputs
		o_data      : out std_logic := '1';
		o_ready     : out std_logic := '1'
	);
end uart;


architecture behave of uart is
	-- state machine type:
	type t_UART_State is (s_Idle, s_Data_Bits, s_Stop_Bit);
	-- variables:
	signal r_UART_State : t_UART_State := s_Idle;
	signal r_Databuffer : std_logic_vector(g_WORDSIZE-1 downto 0);-- := (others => '1');
	signal r_Count : natural range 0 to g_WORDSIZE-1 := g_WORDSIZE-1;
 begin

-- main program
	 p_transmit : process (i_clk) is
	 begin
		 if rising_edge(i_clk) then
            case r_UART_State is
			when s_Idle =>
				if i_dataready='1' then
					-- copy to register
					r_Databuffer <= i_data;
					-- immediately start sending the start bit
					o_data <= '0'; -- begin transmitting the start bit
					o_ready <= '0';
					r_Count <= 0;
					r_UART_State <= s_Data_Bits;
				end if;
			when s_Data_Bits =>
				o_data <= r_Databuffer(r_Count);
				if r_Count = g_WORDSIZE-1 then
					r_UART_State <= s_Stop_Bit;
					o_ready <= '1'; -- because the last bit has just been sent,
									-- it is now safe to load the next word
				else
					r_Count <= r_Count + 1;
				end if;
			when s_Stop_Bit =>
				o_data <= '1';
				r_UART_State <= s_Idle;
			end case;
		end if; -- if rising_edge(i_clk)
	end process;
end behave;
