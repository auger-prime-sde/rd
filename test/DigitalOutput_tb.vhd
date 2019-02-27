library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity DigitalOutput_tb is
end  DigitalOutput_tb;

architecture Behavior of DigitalOutput_tb is

  constant  clk_period 		  : time    := 20 ns;
  constant  g_CMD_BITS        : natural :=  4;
  constant  g_ADDR_BITS       : natural := 12;
  constant  g_DATA_IN_BITS    : natural :=  8;
  constant  g_DATA_OUT_BITS   : natural := 16;
   
   
  signal clk, stop : std_logic := '0';
  signal enable : std_logic := '0';
  signal cmd : std_logic_vector(g_CMD_BITS-1 downto 0);
  signal addr : std_logic_vector(g_ADDR_BITS-1 downto 0);
  signal datain : std_logic_vector( g_DATA_IN_BITS-1 downto 0);
  signal dataout : std_logic_vector( g_DATA_OUT_BITS-1 downto 0);
  signal busy : std_logic := '0';
  
component DigitalOutput is  --begin

 port(	--inputs
		i_clk : in std_logic;
		i_enable : in std_logic;
		i_cmd : in std_logic_vector(3 downto 0); --2
		i_addr : in std_logic_vector(11 downto 0); --7
		i_data : in std_logic_vector(7 downto 0);  --7
	
		--outputs
		o_DataOut : out std_logic_vector (15 downto 0);  
		o_busy	  : out std_logic
);

end component;
 
begin
  -- DUT instantiation
  dut : DigitalOutput
   port map(
    i_clk   		=>  clk,       
	i_enable		=>	enable,
	i_cmd			=>	cmd,
    i_addr 			=>	addr,
    i_data			=>	datain,
	
    o_DataOut 		=>	dataout,
    o_busy			=>	busy
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
  wait for 20 ns;
	assert dataout = "0000000011111111" report "o_DataOut is not initialized all systems on" severity warning;
	wait for 50 ns;
	wait until clk ='1';	
	cmd <= "0000"; 			--write command
	addr <= "UUUUUUUUUUUU";	--Dont care 
	datain <= "01010101";	
	enable <= '1';
 	wait for clk_period;
	enable <= '0';
	assert dataout = "0000000001010101" report "o_DataOut is not written right" severity warning;
	
	wait for 50 ns;	
	
	wait until clk ='1';	
	cmd <=  "0010"; 		-- set to default
	addr <= "UUUUUUUUUUUU";	--Dont care 
	datain <= "UUUUUUUU";	
	enable <= '1';
 	wait for clk_period;
	enable <= '0';
	assert dataout = "0000000011111111" report "o_DataOut is not set to default" severity warning;
	wait for 50 ns;
	
		wait until clk ='1';	
	cmd <=  "0001"; 		-- read data
	addr <= "UUUUUUUUUUUU";	--Dont care 
	datain <= "UUUUUUUU";	
	enable <= '1';
 	wait for clk_period;
	enable <= '0';
	assert dataout = "0000000011111111" report "o_DataOut is not set to default" severity warning;
	wait for 50 ns;
	
	stop <= '1';
    wait;
  end process;
  
end behavior;