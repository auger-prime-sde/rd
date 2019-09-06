--- Data buffer module, dual ported memory to store the sample data

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity housekeeping_buffer is
  generic (
    g_DATA_WIDTH : natural := 8;
    g_ADDRESS_WIDTH : natural := 3
    );
  port (
    -- Write port
    i_write_clk : in std_logic;
    i_write_enable : in std_logic;
    i_write_addr : in std_logic_vector(g_ADDRESS_WIDTH-1 downto 0);
    i_write_data : in std_logic_vector(g_DATA_WIDTH-1 downto 0);
    -- Read port
    i_read_clk : in std_logic;
    i_read_enable: in std_logic;
    i_read_addr : in std_logic_vector(g_ADDRESS_WIDTH-1 downto 0);
    o_read_data : out std_logic_vector(g_DATA_WIDTH-1 downto 0) := (others => '0')
	);
end housekeeping_buffer;

architecture behavioral of housekeeping_buffer is
  type ram_type is array (2**(g_ADDRESS_WIDTH-1)-1 downto 0) of std_logic_vector (g_DATA_WIDTH-1 downto 0);
  signal ram : ram_type := (others => (others => '0'));
  signal data_out_reg : std_logic_vector(g_DATA_WIDTH-1 downto 0) := (others => '0');

begin
  process (i_write_clk)
  begin
    if rising_edge(i_write_clk) then
      if i_write_enable='1' then
        ram(to_integer(unsigned(i_write_addr))) <= i_write_data;
      end if;
    end if;
  end process;
  
  process (i_read_clk)
  begin
    if rising_edge(i_read_clk) then
      if i_read_enable='1' then
        data_out_reg <= ram(to_integer(unsigned(i_read_addr)));
      end if;
    end if;
  end process;

  o_read_data <= data_out_reg;
end behavioral;
