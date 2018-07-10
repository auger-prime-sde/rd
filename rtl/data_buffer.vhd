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
		i_wclk : in std_logic;
		i_we : in std_logic;
		i_waddr : in std_logic_vector(g_ADDRESS_WIDTH-1 downto 0);
		i_wdata : in std_logic_vector(g_DATA_WIDTH-1 downto 0);
    -- Read port
		i_rclk : in std_logic;
		i_re: in std_logic;
		i_raddr : in std_logic_vector(g_ADDRESS_WIDTH-1 downto 0);
		o_rdata : out std_logic_vector(g_DATA_WIDTH-1 downto 0)
	);
end data_buffer;

architecture behavioral of data_buffer is
	type ram_type is array (2**g_ADDRESS_WIDTH-1 downto 0) of std_logic_vector (g_DATA_WIDTH-1 downto 0);
	signal ram : ram_type;
	signal read_addr : std_logic_vector(g_ADDRESS_WIDTH-1 downto 0);

	attribute syn_ramstyle : string;
	attribute syn_ramstyle of ram : signal is "block_ram";

begin
	process (i_wclk)
	begin
		if rising_edge(i_wclk) then
			if i_we='1' then
				ram(to_integer(unsigned(i_waddr)))<=i_wdata;
			end if;
		end if;
	end process;

	process (i_rclk)
	begin
		if rising_edge(i_rclk) then
			if i_re='1' then
				read_addr<=i_raddr;
			end if;
		end if;
	end process;

	o_rdata <=ram(to_integer(unsigned(read_addr)));
end behavioral;
