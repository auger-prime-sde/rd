--- Data buffer module, dual ported memory to store the sample data

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity data_buffer is
  generic (
    g_DATA_WIDTH : natural := 26;
    g_ADDRESS_WIDTH : natural := 11);
	port (
    -- Write port
		i_write_clk : in std_logic;
		i_write_enable : in std_logic;
		i_write_addr : in std_logic_vector(g_ADDRESS_WIDTH-2 downto 0);
		i_write_data : in std_logic_vector(2*g_DATA_WIDTH-1 downto 0);
    -- Read port
		i_read_clk : in std_logic;
		i_read_enable: in std_logic;
		i_read_addr : in std_logic_vector(g_ADDRESS_WIDTH-1 downto 0);
		o_read_data : out std_logic_vector(g_DATA_WIDTH-1 downto 0) := (others => '0')
	);
end data_buffer;

architecture behavioral of data_buffer is
	type ram_type is array (2**(g_ADDRESS_WIDTH-1)-1 downto 0) of std_logic_vector (2*g_DATA_WIDTH-1 downto 0);
	signal ram : ram_type;
    signal r_read_addr : integer range 2 ** (g_ADDRESS_WIDTH - 1) - 1 downto 0;
    signal r_read_data : std_logic_vector(2 * g_DATA_WIDTH-1 downto 0);

begin
	process (i_write_clk)
	begin
		if rising_edge(i_write_clk) then
            if i_write_enable='1' then
              ram(to_integer(unsigned(i_write_addr))) <= i_write_data;
			end if;
		end if;
	end process;


    r_read_addr <= to_integer(unsigned(i_read_addr(g_ADDRESS_WIDTH-1 downto 1)));
    r_read_data <= ram(r_read_addr);
                   
	process (i_read_clk)
	begin
		if rising_edge(i_read_clk) then
            if i_read_enable='1' then
                if i_read_addr(0) = '0' then
                    o_read_data <= r_read_data(2*g_DATA_WIDTH-1 downto g_DATA_WIDTH);
                else
                    o_read_data <= r_read_data(g_DATA_WIDTH-1 downto 0);
                end if;  
			end if;
		end if;
	end process;

end behavioral;
