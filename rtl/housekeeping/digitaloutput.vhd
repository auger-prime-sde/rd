library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity digitaloutput is
generic (
    g_CMD_BITS       : natural := 4;  
    g_DATA_BITS      : natural := 8;
	g_DEFAULT_OUTPUT : std_logic_vector (7 downto 0) := "11111111" 
);
port(	--inputs
		i_clk : in std_logic;
		i_enable : in std_logic;
		i_cmd : in std_logic_vector(g_CMD_BITS-1 downto 0);
		i_data : in std_logic_vector(g_DATA_BITS-1 downto 0);

		--outputs
		o_data : out std_logic_vector (g_DATA_BITS-1 downto 0) := g_DEFAULT_OUTPUT; 
		o_busy	  : out std_logic
);
end  digitaloutput;

architecture Behavioral of digitaloutput is
signal r_data : std_logic_vector(g_DATA_BITS-1 downto 0) := g_DEFAULT_OUTPUT(g_DATA_BITS-1 downto 0);

begin
  o_data <= r_data;
  process (i_Clk)
  begin
    if  rising_edge(i_clk) then
      o_busy <= '1';
      if    (i_enable = '1' and unsigned(i_cmd) = to_unsigned(0, g_DATA_BITS)) then
        -- just read. don't change anything
      elsif (i_enable = '1' and unsigned(i_cmd) = to_unsigned(1, g_DATA_BITS)) then ---Write vector
        r_data <= i_data;
      elsif (i_enable = '1' and unsigned(i_cmd) = to_unsigned(2, g_DATA_BITS)) then --set bit
        r_data <= i_data or  r_data;	
      elsif (i_enable = '1' and unsigned(i_cmd) = to_unsigned(3, g_DATA_BITS)) then --reset bit
        r_data <= not i_data and r_data ;	
      elsif (i_enable = '1' and unsigned(i_cmd) = to_unsigned(4, g_DATA_BITS)) then --set to default
        r_data <= g_DEFAULT_OUTPUT;
      else 
        o_busy <='0';
      end if;
    end if;
  end process;
		
end Behavioral;
