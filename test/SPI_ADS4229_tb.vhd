library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity SPI_ADS4229_tb is 
end SPI_ADS4229_tb;

architecture behavior of SPI_ADS4229_tb is

  constant clk_period : time := 20 ns;
  constant  g_CMD_BITS        : natural :=  4;
  constant  g_ADDR_BITS       : natural := 12;
  constant  g_DATA_IN_BITS    : natural :=  8;
  constant  g_DATA_OUT_BITS   : natural := 16;
 
  constant  g_MOSI_DATA_BITS   : natural := 27;
  constant  g_MISO_DATA_BITS   : natural := 16;
   
   
  signal clk, stop : std_logic := '0';
  signal enable : std_logic := '0';
  signal sclk : std_logic := '0';
  signal spi_mosi : std_logic := '0';
  signal spi_miso : std_logic := '0';
  signal ss_n : STD_LOGIC_VECTOR(0 DOWNTO 0);
  signal cmd : std_logic_vector(g_CMD_BITS-1 downto 0);
  signal addr : std_logic_vector(g_ADDR_BITS-1 downto 0);
  signal datain : std_logic_vector( g_DATA_IN_BITS-1 downto 0);
  signal dataout : std_logic_vector( g_DATA_OUT_BITS-1 downto 0);
  signal busy : std_logic := '0';
  
  signal mosi_data : bit_vector( g_MOSI_DATA_BITS-1 downto 0);
  signal miso_data :std_logic_vector( g_MISO_DATA_BITS-1 downto 0);
  
  component SPI_ADS4229 is
 port(	--inputs
		i_clk : in std_logic;
		i_enable : in std_logic;
		i_cmd : in std_logic_vector(3 downto 0); --2
		i_addr : in std_logic_vector(11 downto 0); --7
		i_data : in std_logic_vector(7 downto 0);  --7
	
		--spi
		o_mosi    : OUT    STD_LOGIC;                      --master out, slave in
		i_miso    : IN     STD_LOGIC;                      --master in, slave out
		o_sclk    : BUFFER STD_LOGIC;                      --spi clock
		o_ss_n    : BUFFER STD_LOGIC_VECTOR(0 DOWNTO 0);   --slave select
		
		--outputs
		o_DataOut : out std_logic_vector (15 downto 0);  
		o_busy	  : out std_logic
);

end component;
 
begin
  -- DUT instantiation
  dut : SPI_ADS4229
   port map(
    i_clk   		=>  clk,       
	i_enable		=>	enable,
	i_cmd			=>	cmd,
    i_addr 			=>	addr,
    i_data			=>	datain,
	
	o_sclk			=>	sclk,
    o_mosi			=>	spi_mosi,
    i_miso			=>	spi_miso,
    o_ss_n			=> ss_n,
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
  
	wait until clk ='1';	
	cmd <= "0010"; --set default settings command
	addr <= "UUUUUUUUUUUU";	--dont care we set default
	datain <= "UUUUUUUU";	--dont care we set default 
	enable <= '1';
 	wait for clk_period*2;
	while (busy ='1') loop
	wait for clk_period;
	end loop;
	enable <= '0';
	
	wait for clk_period*2;	
	
	wait until clk ='1';	
	cmd <= "0000"; --set to write
	addr <= "000000100101";	--adress 25h gain and test patterns
	datain <= "00000011";	--output toggle pattern
	enable <= '1';
 	wait for clk_period*2;
	while (busy ='1') loop
	wait for clk_period;
	end loop;
	enable <= '0';
	
	wait for clk_period*2;	
	
	wait until clk ='1';	
	cmd <= "0001"; --set to read
	addr <= "000011111111";	--adress 
	datain <= "UUUUUUUU";	--dont care we read
	enable <= '1';
 	wait for clk_period*2;
	while (busy ='1') loop
	wait for clk_period;
	end loop;
	enable <= '0';
	
	wait for clk_period*2;	
	
	wait until clk ='1';	
	cmd <= "0000"; --set to read
	addr <= "000011111111";	--adress 
	datain <= "UUUUUUUU";	--dont care we read
	enable <= '1';
 	wait for clk_period*16; --stop halfway
	enable <= '0';
	
	wait for 500 ns;	
		
	stop <= '1';
    wait;

  end process;

end behavior;

