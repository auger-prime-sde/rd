library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity housekeeping2_tb is  --data_writer_tb
end housekeeping2_tb;

architecture behavior of housekeeping2_tb is

  constant clk_period : time := 20 ns;
  constant spi_clk_period : time := 52 ns;
  constant g_DEV_SELECT_BITS : natural :=  3;
  constant  g_CMD_BITS        : natural :=  4;
  constant  g_ADDR_BITS       : natural := 12;
  constant  g_DATA_IN_BITS    : natural :=  8;
  constant  g_DATA_OUT_BITS   : natural := 16;
  constant  g_MOSI_DATA_BITS   : natural := 27;
  constant  g_MISO_DATA_BITS   : natural := 16;
   
   
  signal clk, stop : std_logic := '0';
  signal spi_clk : std_logic := '1';
  signal stop_spi_clk : std_logic := '1';
  signal spi_mosi : std_logic := '0';
  signal spi_miso : std_logic := '0';
  signal device_select : std_logic_vector(g_DEV_SELECT_BITS-1 downto 0);
  signal cmd : std_logic_vector(g_CMD_BITS-1 downto 0);
  signal addr : std_logic_vector(g_ADDR_BITS-1 downto 0);
  signal datain : std_logic_vector( g_DATA_IN_BITS-1 downto 0);
  signal dataout : std_logic_vector( g_DATA_OUT_BITS-1 downto 0);
  signal busy : std_logic := '0';
  signal mosi_data : bit_vector( g_MOSI_DATA_BITS-1 downto 0);
  signal miso_data :std_logic_vector( g_MISO_DATA_BITS-1 downto 0);
  component housekeeping is
  generic (
    g_DEV_SELECT_BITS : natural :=  3;
    g_CMD_BITS        : natural :=  4;
    g_ADDR_BITS       : natural := 12;
    g_DATA_IN_BITS    : natural :=  8;
    g_DATA_OUT_BITS   : natural := 16
    );
  port (
    i_clk            : in std_logic;
    -- signals to/from UUB
    i_spi_clk        : in std_logic;
    i_spi_mosi       : in std_logic;
    o_spi_miso       : out std_logic;
    --signals to housekeeping sub-modules
    o_device_select  : out std_logic_vector(g_DEV_SELECT_BITS-1 downto 0);
    o_cmd            : out std_logic_vector(g_CMD_BITS-1 downto 0);
    o_addr           : out std_logic_vector(g_ADDR_BITS-1 downto 0);
    o_datain         : out std_logic_vector(g_DATA_IN_BITS-1 downto 0);
    i_dataout        : in std_logic_vector(g_DATA_OUT_BITS-1 downto 0);
    i_busy           : in std_logic
    );

end component;
 
begin
  -- DUT instantiation
  dut : housekeeping 
   port map(
    i_clk   		=>  clk,       
	
    i_spi_clk 		=>	spi_clk,
    i_spi_mosi		=>	spi_mosi,
    o_spi_miso		=>	spi_miso,
     
    o_device_select	=> 	device_select,
    o_cmd			=>	cmd,
    o_addr 			=>	addr,
    o_datain		=>	datain,
    i_dataout 		=>	dataout,
    i_busy			=>	busy
    );

  p_clk : process is
  begin
    -- Finish simulation when stop is asserted
    if stop = '1' then
	--report "stop=1";
      wait;
    end if;

    clk <= '0';
	--report "clk";
    wait for clk_period / 2;
    clk <= '1';
    wait for clk_period / 2;
  end process;

p_spi_clk : process is
  begin
     if stop = '1' then
	--  report "stop_spi";
      wait;
    end if;
    -- spi_clk can start anytime
	--	report "clk_spi";
	if stop_spi_clk  = '0' then
		spi_clk <= '0';
	--	report "clk_spi_run";
		wait for spi_clk_period / 2;
		spi_clk <= '1';
		wait for spi_clk_period / 2;
	else
		wait for spi_clk_period;
	end if;
  end process;
  
  p_test : process is
  begin
  
	wait for 100 ns;
    stop_spi_clk <= '0';
	mosi_data <= B"011_0010_101010101010_11001100"; --send command to device 0010
	busy <= '0';			
	
	report "send command  0010 to device 011";
	 for i in 0 to (g_MOSI_DATA_BITS + g_DATA_OUT_BITS)-1 loop
		if i <= g_MOSI_DATA_BITS-1 then --write part of spi
			spi_mosi <= to_stdulogic (mosi_data((g_MOSI_DATA_BITS-1)-i));
		elsif i = (g_MOSI_DATA_BITS) then 	
          busy <= '1';
          report "checking output at time " & time'image(now);
          assert device_select = "011" report "Device select failt " severity warning;
          assert cmd = "0010" report "CMD out failt " severity warning;
          assert addr = "101010101010" report "addres out failt " severity warning;
          assert datain = "11001100" report "datain out failt " severity warning;
		end if;	
		
		wait for spi_clk_period;
	 end loop;
	 
	 stop_spi_clk <= '1';
     wait for spi_clk_period*2;
	 dataout <= "1111000011110000";
	 busy <= '0';
	 mosi_data <= B"000_0010_000000000000_00000000";
	 stop_spi_clk <= '0';
	 
	report "forward data from bus to miso";
	 for i in 0 to (g_MOSI_DATA_BITS + g_DATA_OUT_BITS)-1 loop
		if i < g_MOSI_DATA_BITS-1 then --write part of spi
			spi_mosi <= to_stdulogic (mosi_data((g_MOSI_DATA_BITS-1)-i));
		elsif i = (g_MOSI_DATA_BITS)-1 then 
			spi_mosi <= to_stdulogic (mosi_data((g_MOSI_DATA_BITS-1)-i));		
			miso_data(i-(g_MOSI_DATA_BITS-1)) <= spi_miso;
		elsif i > (g_MOSI_DATA_BITS)-1 then 	
			miso_data(i-g_MOSI_DATA_BITS) <= spi_miso;
		end if;	
		wait for spi_clk_period;
	 end loop;	

    
		
		report "stop_spi";
    
	stop <= '1';
    wait;

  end process;

end behavior;
