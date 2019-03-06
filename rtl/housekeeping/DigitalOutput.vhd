library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity DigitalOutput is
generic (
    g_CMD_BITS        : natural :=  4;  
    g_ADDR_BITS       : natural := 12;
    g_DATA_IN_BITS    : natural :=  8;
    g_DATA_OUT_BITS   : natural := 16;
	g_DEFAULT_OUTPUT  : std_logic_vector (15 downto 0) := "0000000011111111" --we only use the last 8 bits for output so default all outputs are high
);
port(	--inputs
		i_clk : in std_logic;
		i_enable : in std_logic;
		i_cmd : in std_logic_vector(g_CMD_BITS-1 downto 0);
		i_addr : in std_logic_vector(g_ADDR_BITS-1 downto 0);
		i_data : in std_logic_vector(g_DATA_IN_BITS-1 downto 0);

		--outputs
		o_DataOut : out std_logic_vector (g_DATA_OUT_BITS-1 downto 0) := g_DEFAULT_OUTPUT; 
		o_busy	  : out std_logic
);
end  DigitalOutput;

architecture Behavioral of DigitalOutput is
signal s_data : std_logic_vector(g_DATA_IN_BITS-1 downto 0) := g_DEFAULT_OUTPUT(g_DATA_IN_BITS-1 downto 0);
signal s_prev_data : std_logic_vector(g_DATA_IN_BITS-1 downto 0) := g_DEFAULT_OUTPUT(g_DATA_IN_BITS-1 downto 0);

begin

process (i_Clk)

begin
if  falling_edge(i_clk) then
	
	if (i_enable = '1' and i_cmd = "0000") then ---Write vector
	o_busy <='1';
	o_dataOut (g_DATA_IN_BITS-1 downto 0) <= i_data;
	s_prev_data <= i_data;
	elsif (i_enable = '1' and i_cmd = "0001") then --set bit
	o_busy <='1';
	o_dataOut (g_DATA_IN_BITS-1 downto 0) <= i_data or  s_data ;	
	s_prev_data <= i_data or  s_data ;
	elsif (i_enable = '1' and i_cmd = "0010") then --reset bit
	o_busy <='1';
	o_dataOut (g_DATA_IN_BITS-1 downto 0) <= not i_data and  s_data ;	
	s_prev_data <= not i_data and  s_data ;
	elsif (i_enable = '1' and i_cmd = "0011") then --set to default
	o_busy <='1';
	o_dataOut <= g_DEFAULT_OUTPUT;
	s_prev_data <= g_DEFAULT_OUTPUT (g_DATA_IN_BITS-1 downto 0);
	else 
	o_busy <='0';
	s_data <= s_prev_data;
	end if;
end if;
	end process;
		
end Behavioral;