library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


entity SPI_ADS4229 is
generic (
    g_CMD_BITS        : natural :=  4;
    g_ADDR_BITS       : natural := 12;
    g_DATA_IN_BITS    : natural :=  8;
    g_DATA_OUT_BITS   : natural := 16
);
port(	--inputs
		i_clk : in std_logic;
		i_enable : in std_logic;
		i_cmd : in std_logic_vector(g_CMD_BITS-1 downto 0);
		i_addr : in std_logic_vector(g_ADDR_BITS-1 downto 0);
		i_data : in std_logic_vector(g_DATA_IN_BITS-1 downto 0);
	
		--spi
		o_mosi    : OUT    STD_LOGIC;                      --master out, slave in
		i_miso    : IN     STD_LOGIC;                      --master in, slave out
		o_sclk    : BUFFER STD_LOGIC;                      --spi clock
		o_ss_n    : BUFFER STD_LOGIC_VECTOR(0 DOWNTO 0);   --slave select
		
		--outputs
		o_DataOut : out std_logic_vector (g_DATA_OUT_BITS-1 downto 0);  
		o_busy	  : out std_logic
);
end  SPI_ADS4229;

architecture Behavioral of SPI_ADS4229 is

-- state machine states
constant c_Idle_State : std_logic_vector (5 downto 0) := "000001";
constant c_InitReadout_State : std_logic_vector (5 downto 0) := "000010";  
constant c_ReadWrite_State : std_logic_vector (5 downto 0) := "000100";
constant c_ResetReadout_state : std_logic_vector (5 downto 0) := "001000";
constant c_Done_state : std_logic_vector (5 downto 0) := "010000";
constant c_DefaultSettings_State : std_logic_vector (5 downto 0) := "100000";

signal s_State : std_logic_vector (5 downto 0) := "000001";
signal s_TX_Data : std_logic_vector (15 DOWNTO 0);
signal s_DataOut: std_logic_vector (15 DOWNTO 0);
signal s_reset_n : std_logic := '1';
signal s_busy : std_logic;
signal s_enable : std_logic := '0';
signal s_cmd : std_logic_vector (g_CMD_BITS-1 DOWNTO 0); --2
signal s_addr : std_logic_vector(g_ADDR_BITS-1 downto 0); --7
signal s_data : std_logic_vector(g_DATA_IN_BITS-1 downto 0); --7
signal s_lastBusyState : std_logic := '0';
--signal s_wait  : natural := 10;

--array for default settings
type t_settings_array is array (0 to 4) of std_logic_vector (15 downto 0);
signal s_setting : t_settings_array;
signal s_index : integer range 0 to 5 :=0;


component spi_master	--component decliration SPI Master
    GENERIC(
    slaves  : INTEGER := 1;  --number of spi slaves
    d_width : INTEGER := 16); --data bus width
  PORT(
    clock   : IN     STD_LOGIC;                             --system clock
    reset_n : IN     STD_LOGIC;                             --asynchronous reset
    enable  : IN     STD_LOGIC;                             --initiate transaction
    cpol    : IN     STD_LOGIC;                             --spi clock polarity
    cpha    : IN     STD_LOGIC;                             --spi clock phase
    cont    : IN     STD_LOGIC;                             --continuous mode command
    clk_div : IN     INTEGER;                               --system clock cycles per 1/2 period of sclk
    addr    : IN     INTEGER;                               --address of slave
    tx_data : IN     STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);  --data to transmit
    miso    : IN     STD_LOGIC;                             --master in, slave out
    sclk    : BUFFER STD_LOGIC;                             --spi clock
    ss_n    : BUFFER STD_LOGIC_VECTOR(slaves-1 DOWNTO 0);   --slave select
    mosi    : OUT    STD_LOGIC;                             --master out, slave in
    busy    : OUT    STD_LOGIC;                             --busy / data ready signal
    rx_data : OUT    STD_LOGIC_VECTOR(d_width-1 DOWNTO 0)   --data received
	); 
	end component;
	
begin
SPIcom : spi_master
	GENERIC MAP(
			slaves => 1,  
			d_width => 16
			) 
	PORT MAP(
		clock => i_clk,
		reset_n => s_reset_n,
		enable => s_enable,
		cpol => '1',	--'1' =normal high
		cpha => '0',	--first bit written on ss faling edge
		cont => '0',
		clk_div => 1,
		addr => 0,    
		tx_data => s_TX_Data,
		miso => i_miso, 
		sclk => o_sclk,
		ss_n => o_ss_n,
		mosi => o_mosi,
		busy => s_busy,
		rx_data => s_DataOut
		); 
	
process (i_Clk)
	begin	
	
s_setting(0) <= "0000000000000010"; --Reset Registers to factory default
s_setting(1) <= "1100110000000000"; --test value!!
s_setting(2) <= "1110001100000000";	--test value!!
s_setting(3) <= "1111000000000000"; --test value!!
s_setting(4) <= "1111100000000000"; --test value!!


		if rising_edge(i_clk) then 
				
			Case s_state is
	---------------------------------------------------	
		When c_Idle_state =>		--1
			if (i_enable = '1') then
				s_cmd <= i_cmd;
				s_addr <= i_addr;
				s_data <= i_data;
				s_state <= c_InitReadout_State;
				o_busy <= '1';		--set the busy flag for houskeeping controller
				if (s_cmd = "0000" and i_enable = '1' and s_busy = '0') then--write command  -- and s_wait > 0
					s_TX_Data <= "0000000000000000"; --adres of readout register is 00h and for write you write 00h
					s_enable <= '1';
				elsif (s_cmd = "0001" and i_enable = '1' and s_busy = '0') then --read command -- and s_wait > 0
					s_TX_Data <= "0000000000000001"; --adres of readout register is 00h and for write you write 01h
					s_enable <= '1';
				elsif (s_cmd = "0010" and i_enable = '1' and s_busy = '0') then --set default settings -- and s_wait > 0
					s_TX_Data <= "0000000000000000"; --set to write
					s_enable <= '1';
				else
					s_state <= c_Idle_state;
				end if;
			else
				s_state <= c_Idle_state;
			end if;
	---------------------------------------------------
			When c_InitReadout_State =>		--2
			
				if (s_busy = '0' and s_lastBusyState ='0')then
					s_lastBusyState <= '0';
				elsif (s_busy = '1') then
					s_lastBusyState <= '1';
					s_enable <= '0'; 
				elsif (s_busy = '0' and s_lastBusyState ='1' ) then --falling edge of bussy
					if (s_cmd ="0010") then
					s_state <= c_DefaultSettings_State;
					s_lastBusyState <= '0';
					s_enable <= '1';
					s_TX_Data <= s_setting(s_index);
					s_index <= s_index + 1;
					else
					s_state <= c_ReadWrite_State;
					s_lastBusyState <= '0';
					s_enable <= '1';
					s_TX_Data (15 DOWNTO 8) <= s_addr (7 downto 0);
					s_TX_Data (7 DOWNTO 0) <= s_data(7 downto 0);
					end if;
				else
					s_state <= c_Idle_state;
				end if;
				
	---------------------------------------------------		
			When c_ReadWrite_State =>	--4
				
					
				if (s_busy = '0' and s_lastBusyState ='0')then
					s_lastBusyState <= '0';
				elsif (s_busy = '1') then
					s_lastBusyState <= '1';
					s_enable <= '0';
				elsif (s_busy = '0' and s_lastBusyState ='1' ) then --faling edge of busy
					s_state <= c_ReadWrite_State;
					s_lastBusyState <= '0';
					s_enable <= '0';
					if (s_cmd = "0000" and s_busy = '0' and i_enable = '1') then  --wait until spi master is done
						s_enable <= '1';																				
						o_DataOut <= "0000000000000000";
						s_state <= c_ResetReadout_state;
					elsif (s_cmd = "0001" and s_busy = '0' and i_enable = '1') then	--wait until spi master is done
						s_enable <= '1';																				
						o_DataOut <= s_DataOut;
						s_state <= c_ResetReadout_state;
					else
						s_state <= c_Idle_state;
					end if;
				end if;	
	-----------------------------------------------------------------------------------
				
			When c_ResetReadout_state =>		--8
				if (s_busy = '0' and s_lastBusyState ='0')then
					s_lastBusyState <= '0';
				elsif (s_busy = '1') then
					s_lastBusyState <= '1';
					s_enable <= '0';
				elsif (s_busy = '0' and s_lastBusyState ='1' ) then --faling edge of busy
					s_enable <= '0';
					s_state <= c_Done_state;
				else
					s_state <= c_Idle_state;
				end if;	
				
	---------------------------------------------------		
			When c_Done_state =>		--16
				if (i_enable = '1')	then
					if (s_busy = '0') then	--wait until spi master is done
					s_state <= c_Idle_state;
					s_enable <= '0';
					o_busy <= '0';
					s_index <= 0;
					end if;
				else
				s_state <= c_Idle_state;
				end if;
	 ---------------------------------------------------	
			When c_DefaultSettings_State =>	--32
				if (s_busy = '0' and s_lastBusyState ='0')then
					s_lastBusyState <= '0';
				elsif (s_busy = '1') then
					s_lastBusyState <= '1';
					s_enable <= '0';
				elsif (s_busy = '0' and s_lastBusyState ='1' ) then --faling edge of busy
					if (s_index < 5) then
					s_lastBusyState <= '0';
					s_TX_Data <= s_setting(s_index);
					s_index <= s_index + 1;
					s_enable <= '1';
					o_DataOut <= "0000000000000000";
					else
					s_lastBusyState <= '0';
					s_index <= 0;
					s_enable <= '1';
					s_state <= c_ResetReadout_state;
					s_TX_Data <= "0000000000000001"; --adres of readout register is 00h and for write you write 01h
					end if;
				else
					s_state <= c_Idle_state;
				end if;	
			
  
	---------------------------------------------------		
			When others =>
					s_State <= c_Idle_state;
					
			end case;
		end if;
		
	end process;
		
end Behavioral;