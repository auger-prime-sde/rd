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
    i_read_addr : in std_logic_vector(g_ADDRESS_WIDTH-1 downto 0);
    o_byte_data : out std_logic_vector(7 downto 0);
    o_full_data : out std_logic_vector(g_DATA_WIDTH * 2 ** g_ADDRESS_WIDTH - 1 downto 0) := (others => '0');
    i_latch : in std_logic
	);
end housekeeping_buffer;

architecture behavioral of housekeeping_buffer is
  type ram_type is array (2**(g_ADDRESS_WIDTH)-1 downto 0) of std_logic_vector (g_DATA_WIDTH-1 downto 0);
  signal data_buffer : ram_type;
  signal output_buffer : ram_type;
  
begin
  gen_assign: for i in 2**g_ADDRESS_WIDTH-1 downto 0 generate
    o_full_data((i+1)*g_DATA_WIDTH-1 downto i*g_DATA_WIDTH) <= output_buffer(i);
  end generate gen_assign;
  
  
  process (i_write_clk)
  begin
    if rising_edge(i_write_clk) then
      -- write input
      if i_write_enable='1' then
        data_buffer(to_integer(unsigned(i_write_addr))) <= i_write_data;
      end if;
      -- latch output
      if i_latch = '0' then
        output_buffer <= data_buffer;
      end if;
      -- selected output
      o_byte_data <= output_buffer(to_integer(unsigned(i_read_addr)));
    end if;
  end process;  
  
end behavioral;
