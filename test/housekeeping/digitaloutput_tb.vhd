library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity digitaloutput_tb is
end  digitaloutput_tb;

architecture Behavior of digitaloutput_tb is

  constant  clk_period 	: time    := 20 ns;
  constant  g_CMD_BITS  : natural := 4;
  constant  g_DATA_BITS : natural := 8 ;
   
   
  signal clk, stop : std_logic := '0';
  signal enable : std_logic := '0';
  signal cmd : std_logic_vector(g_CMD_BITS-1 downto 0);
  signal datain : std_logic_vector( g_DATA_BITS-1 downto 0);
  signal dataout : std_logic_vector( g_DATA_BITS-1 downto 0);
  signal busy : std_logic := '0';
  
component digitaloutput is  --begin
  generic (
    g_CMD_BITS       : natural := 4;
    g_DATA_BITS      : natural := 8;
    g_DEFAULT_OUTPUT : std_logic_vector(7 downto 0) := "11111111"
    );
  port(	--inputs
    i_clk        : in std_logic;
    i_enable     : in std_logic;
    i_cmd        : in std_logic_vector(g_CMD_BITS-1 downto 0);
    i_data       : in std_logic_vector(g_DATA_BITS-1 downto 0);
    --outputs
    o_data       : out std_logic_vector (g_DATA_BITS-1 downto 0);  
    o_busy	     : out std_logic
    );

end component;
 
begin
  -- DUT instantiation
  dut : digitaloutput
    generic map (
      g_CMD_BITS       => g_CMD_BITS,
      g_DATA_BITS      => g_DATA_BITS,
      g_DEFAULT_OUTPUT => "11111111"
      )
    port map(
      i_clk   		=>  clk,       
      i_enable		=>	enable,
      i_cmd			=>	cmd,
      i_data		=>	datain,
      o_data    	=>	dataout,
      o_busy		=>	busy
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
    assert dataout = "11111111" report "o_DataOut is not initialized all systems on" severity warning;
    wait for 40 ns;
    
    wait until clk ='0';	
    cmd <= "0001"; 			--write vector command
    datain <= "01010101";	
    enable <= '1';
    wait for clk_period;
    enable <= '0';
    assert dataout = "01010101" report "o_DataOut is not written right" severity warning;
    
    wait for 50 ns;	
    
    wait until clk ='0';	
    cmd <=  "0100"; 		-- set to default
    datain <= "UUUUUUUU";	
    enable <= '1';
    wait for clk_period;
    enable <= '0';
    assert dataout = "11111111" report "o_DataOut is not set to default" severity warning;
    wait for 50 ns;
    
    wait until clk ='0';	
    cmd <=  "0011"; 		-- reset bit
    datain <= "01010101";	
    enable <= '1';
    wait for clk_period;
    enable <= '0';
    assert dataout = "10101010" report "o_DataOut is not set to default" severity warning;
    wait for 50 ns;
    
    wait until clk ='0';	
    cmd <=  "0010"; 		-- set bit
    datain <= "00010100";	
    enable <= '1';
    wait for clk_period;
    enable <= '0';
    assert dataout = "10111110" report "o_DataOut is not set to default" severity warning;
    wait for 50 ns;
    
    stop <= '1';
    wait;
  end process;
  
end behavior;
