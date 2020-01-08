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
    o_read_data : out std_logic_vector(g_DATA_WIDTH-1 downto 0) := (others => '0');
    i_write_latch : in std_logic;
    i_read_latch : in std_logic;
    o_latched: out std_logic_vector(2**g_ADDRESS_WIDTH*g_DATA_WIDTH-1 downto 0)
	);
end housekeeping_buffer;

architecture behavioral of housekeeping_buffer is
  type ram_type is array (2**(g_ADDRESS_WIDTH)-1 downto 0) of std_logic_vector (g_DATA_WIDTH-1 downto 0);
  --signal ram : ram_type;-- := (others => (others => '0'));
  signal write_buffer : ram_type;
  signal latch_buffer : ram_type;
  signal read_buffer  : ram_type;
  
  signal data_out_reg : std_logic_vector(g_DATA_WIDTH-1 downto 0) := (others => '0');
  attribute syn_ramstyle : string;
  --attribute syn_ramstyle of ram : signal is "block_ram";
  attribute syn_ramstyle of write_buffer : signal is "block_ram";
  attribute syn_ramstyle of latch_buffer : signal is "block_ram";
  attribute syn_ramstyle of read_buffer  : signal is "block_ram";

begin
  gen_assign: for i in 2**g_ADDRESS_WIDTH-1 downto 0 generate
    o_latched((i+1)*g_DATA_WIDTH-1 downto i*g_DATA_WIDTH) <= latch_buffer(i);
  end generate gen_assign;
  
  
  process (i_write_clk)
  begin
    if rising_edge(i_write_clk) then
      if i_write_enable='1' then
        write_buffer(to_integer(unsigned(i_write_addr))) <= i_write_data;
      end if;

      if i_write_latch = '1' then
        latch_buffer <= write_buffer;
      end if;
    end if;
  end process;
  
  process (i_read_clk)
  begin
    if rising_edge(i_read_clk) then
      if i_read_enable='1' then
        o_read_data <= read_buffer(to_integer(unsigned(i_read_addr)));
      end if;

      if i_read_latch = '1' then
        read_buffer <= latch_buffer;
      end if;
    end if;
  end process;

end behavioral;
