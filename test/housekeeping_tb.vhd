library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity housekeeping_tb is  --data_writer_tb
end housekeeping_tb;

architecture behavior of housekeeping_tb is

  constant clk_period : time := 20 ns;
  constant spi_clk_period : time := 52 ns;
  constant g_DEV_SELECT_BITS : natural :=  3;
  constant  g_CMD_BITS        : natural :=  4;
  constant  g_ADDR_BITS       : natural := 12;
  constant  g_DATA_IN_BITS    : natural :=  8;
  constant  g_DATA_OUT_BITS   : natural := 16;
  constant  g_MOSI_DATA_BITS   : natural := g_DEV_SELECT_BITS+g_CMD_BITS+g_ADDR_BITS+g_DATA_IN_BITS;
  constant  g_MISO_DATA_BITS   : natural := g_DATA_OUT_BITS;
   
   
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
    mosi_data <= B"000_0001_000000000000_00000000"; --get busy state
	busy <= '1';			
	stop_spi_clk <= '0';



    
    report "get busy state first attempt";
    -- write part of spi
    for i in 0 to g_MOSI_DATA_BITS-1 loop
      -- write data when clock goes low
      wait until spi_clk = '0';
      spi_mosi <= to_stdulogic (mosi_data((g_MOSI_DATA_BITS-1)-i));
    end loop;
    -- we are left at the start of the last bit so we wait one clock period for
    -- that bit to finish.
    wait for spi_clk_period;
    spi_mosi <= 'U'; -- last bit finished, should no longer care

    -- read part of spi
    for i in 0 to g_MISO_DATA_BITS-1 loop
      -- read data when clock goes high
      wait until spi_clk = '1';
      assert spi_miso = busy report "spi_miso not high after request busy while busy" severity warning;
    end loop;

    

    
    --stop_spi_clk <= '1';
    --wait for 100 ns;
	--	assert spi_miso ='0' report "spi_miso not low after request bussy while bussy done" severity warning; --controleer default
    busy <= '0';
    stop_spi_clk <= '0';
	report "get busy state second attempt";
    -- write part of spi
    for i in 0 to g_MOSI_DATA_BITS-1 loop
      -- write data when clock goes low
      wait until spi_clk = '0';
      spi_mosi <= to_stdulogic (mosi_data((g_MOSI_DATA_BITS-1)-i));
    end loop;
    -- we are left at the start of the last bit so we wait one clock period for
    -- that bit to finish.
    wait for spi_clk_period;
    spi_mosi <= 'U'; -- last bit finished, should no longer care
    -- read part of spi
    for i in 0 to g_MISO_DATA_BITS-1 loop
      -- read data when clock goes high
      wait until spi_clk = '1';
      assert spi_miso = busy report "spi_miso not high after request busy while busy" severity warning;
    end loop;
    stop_spi_clk <= '1';


    
    wait for 10 * spi_clk_period;


    
    report "get busy state third attempt";
    busy <= '1';
    stop_spi_clk <= '0';
    -- write part of spi
    for i in 0 to g_MOSI_DATA_BITS-1 loop
      -- write data when clock goes low
      wait until spi_clk = '0';
      spi_mosi <= to_stdulogic (mosi_data((g_MOSI_DATA_BITS-1)-i));
    end loop;
    -- we are left at the start of the last bit so we wait one clock period for
    -- that bit to finish.
    wait for spi_clk_period;
    spi_mosi <= 'U'; -- last bit finished, should no longer care
    -- read part of spi
    for i in 0 to g_MISO_DATA_BITS-1 loop
      -- read data when clock goes high
      wait until spi_clk = '1';
      assert spi_miso = busy report "spi_miso not high after request busy while busy" severity warning;
    end loop;
    stop_spi_clk <= '1';
    
    
   
	wait for 10 * spi_clk_period;
	--assert spi_miso ='0' report "spi_miso not low after request bussy done" severity warning; --controleer default 
    
		
    report "stop_spi";
    
	stop <= '1';
    wait;

  end process;

end behavior;
