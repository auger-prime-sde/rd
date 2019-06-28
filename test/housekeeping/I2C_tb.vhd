library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity I2C_tb is 
end I2C_tb;

architecture behavior of I2C_tb is

  constant clk_period : time := 20 ns;
  constant  g_CMD_BITS        : natural := 4;
  constant  g_ADDR_BITS       : natural := 8;
  constant  g_DATA_IN_BITS    : natural := 8;
  constant  g_DATA_OUT_BITS   : natural := 16;
 
  signal clk, stop : std_logic := '0';
  signal enable : std_logic := '0';
  signal cmd : std_logic_vector(g_CMD_BITS-1 downto 0);
  signal addr : std_logic_vector(g_ADDR_BITS-1 downto 0);
  signal datain : std_logic_vector( g_DATA_IN_BITS-1 downto 0);
  signal dataout : std_logic_vector( g_DATA_OUT_BITS-1 downto 0);
  signal busy : std_logic := '0';
  signal sda : std_logic;
  signal scl : std_logic;
  
	component I2C is
  port(	--inputs
		i_clk : in std_logic;
		i_enable : in std_logic;
		i_cmd : in std_logic_vector(g_CMD_BITS-1 downto 0);
		i_addr : in std_logic_vector(g_ADDR_BITS-1 downto 0);
		i_data : in std_logic_vector(g_DATA_IN_BITS-1 downto 0);

		--outputs
		o_DataOut : out std_logic_vector (g_DATA_OUT_BITS-1 downto 0); 
		o_busy	  : out std_logic;
		
		sda	  : inout std_logic;
		scl	  : inout std_logic
		);
end component;

begin
	--DUT instantiation
	dut : I2C
		Port map(
			i_clk		=> clk,
			i_enable	=> enable,
			i_cmd		=> cmd,
			i_addr		=> addr,
			i_data		=> datain,
			o_DataOut	=> dataout,
			o_busy		=> busy,
			sda			=> sda,
			scl			=> scl
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
	--wait for 155000 ns;
	for t in 0 to 8 loop
      wait for 1 ms;
      report "progress: " & integer'image(t);
    end loop;
      


	stop <= '1';
    wait;

  end process;

end behavior;
