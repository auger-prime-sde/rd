library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- TODOS:
-- latch output data while sampling (to prevent sending half of the previous
-- and half of the next sample)
-- simplify code (e.g. check if all busy asserts are really needed)
-- add a config register where you can set the update rate
-- add temperature sensor code


entity I2C is
generic (
    g_CMD_BITS        : natural :=  4;  
    g_ADDR_BITS       : natural := 8;
    g_DATA_IN_BITS    : natural :=  8;
    g_DATA_OUT_BITS   : natural := 64;
	g_number_of_channels : natural := 4;
	g_number_of_I2C_Chips : natural := 1
	);
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
end  I2C;

architecture Behavioral of I2C is

--constants and signals

-- state machine states
constant c_Idle_State : std_logic_vector (2 downto 0) := "001";
constant c_Write_State : std_logic_vector (2 downto 0) := "010";  
constant c_Read_State : std_logic_vector (2 downto 0) := "100";
--constant c_DefaultSettings_State : std_logic_vector (5 downto 0) := "001000";
--constant c_Done_state : std_logic_vector (5 downto 0) := "010000";

signal s_State : std_logic_vector (2 downto 0) := "001";
signal s_reset : std_logic;
signal s_enable : std_logic;
signal s_busy : std_logic :='0';
signal s_rw: std_logic;
signal s_triggercount: unsigned (31 downto 0)  := "00000000000000000000000000000000"; 
signal s_datacount: unsigned  (1 downto 0) := "00";
signal s_addr :  std_logic_vector (6 downto 0);
signal s_error : std_logic;
signal s_data_wr : std_logic_vector (7 downto 0);
signal s_data_r : std_logic_vector (7 downto 0);
signal s_lastBusyState : std_logic :='0';

--array for default configuration
type t_configuration_array is array (0 to 3) of std_logic_vector (15 downto 0);
signal s_configuration : t_configuration_array;
signal s_index_configuration : integer range 0 to 4 :=0;

--array for sensor measurment
type t_data_array is array (0 to 3) of std_logic_vector (15 downto 0);
signal s_data : t_data_array := ("0000000000000000", "0000000000000000", "0000000000000000", "0000000000000000");
signal s_index_data : integer range 0 to 3 :=0;

--array for sensor adress
type t_adress_array is array (0 to 1) of std_logic_vector (6 downto 0);
signal s_adress : t_adress_array;
signal s_index_adress : integer range 0 to 2 :=0;

signal i2c_clk : std_logic;


component i2c_master2 	--component decliration i2c_master
  PORT(
    i_clk          : IN     STD_LOGIC;                    --system clock
    i_enable       : IN     STD_LOGIC;                    --latch in command
    i_address      : IN     STD_LOGIC_VECTOR(6 DOWNTO 0); --address of target slave
    i_rw           : IN     STD_LOGIC;                    --'0' is write, '1' is read
    i_data         : IN     STD_LOGIC_VECTOR(7 DOWNTO 0); --data to write to slave
    o_busy         : OUT    STD_LOGIC;                    --indicates transaction in progress
    o_data         : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data read from slave
    o_scl          : out    STD_LOGIC;                   --serial clock output of i2c bus
    io_sda         : INOUT  STD_LOGIC);                    --serial data output of i2c bus
end component;

component clock_divider
  generic (
    g_MAX_COUNT : natural
    );  
  port(
    i_clk : in std_logic;
    o_clk : out std_logic
    );
end component;
	
begin

  clk_divider : clock_divider
    generic map (
      g_MAX_COUNT => 10000
      )
    port map (
      i_clk => i_clk,
      o_clk => i2c_clk
      );
  
I2Ccom : i2c_master2
  port map(
    i_clk			 => i2c_clk,          	--system clock
    i_enable         => s_enable,           --latch in command
    i_address     	 =>	s_addr (6 downto 0), --address of target slave
    i_rw             => s_rw,           	--'0' is write, '1' is read
    i_data   	     =>	s_data_wr,			--data to write to slave
    o_busy           => s_busy,        		--indicates transaction in progress
    o_data    	     =>	s_data_r,			--data read from slave
    o_scl            => scl,          		--serial clock output of i2c bus
    io_sda           => sda           		--serial data output of i2c bus
	);

	s_configuration(0) <= "1100010110000011"; --settings channel 0
	s_configuration(1) <= "1101010110000011"; --settings channel 1
	s_configuration(2) <= "1110010110000011"; --settings channel 2
	s_configuration(3) <= "1111010110000011"; --settings channel 3

	--s_data(0) <= "0000000000000000";	--data channel 0 sensor 0
	--s_data(1) <= "0000000000000000";	--data channel 0 sensor 0
	--s_data(2) <= "0000000000000000";	--dat"", ""hannel 0 sensor 0
	--s_data(3) <= "0000000000000000";	--dat"", ""hannel 0 sensor 0
	
	s_adress(0) <= "1001000"; 			--I2C sensor adres
	s_adress(1) <= "1001001"; 			--I2C sensor adres


  o_dataout(15 downto 0) <= s_data(0);
  o_dataout(31 downto 16) <= s_data(1);
  o_dataout(47 downto 32) <= s_data(2);
  o_dataout(63 downto 48) <= s_data(3);
  
  
process (i_Clk)
	begin	
	if rising_edge(i_clk) then 
	s_triggercount <= s_triggercount + 1;
    Case s_state is
	---------------------------------------------------	
		When c_Idle_state =>		--1
			if (i_enable = '1' and i_cmd > "1000" and i_cmd < "1100") then  --read data from buffer
				o_busy <= '1';
				--o_DataOut <= s_data(to_integer(signed(i_cmd)));
            --  "10110010110100000101111000000000"
            --"0000000000000000011000000000000")
			elsif ((i_enable = '1' and i_cmd > "0001") or (s_triggercount > "0000001100000000000000000000000"))then --force I2C read or read all sensors every 60 seconds @ 50.000.000hz !!controle op busy
				o_busy <= '1';
				s_state <= c_Write_State;
				s_triggercount <= (others=>'0');
--to_unsigned(0,32);								--reset trigger count
				s_enable <= '1';
				s_addr <= s_adress(s_index_adress);
				s_rw <= '0'; 														--set to write
				s_data_wr <= "00000001";											--write 01 to pointer register for acces to configuration register				
			else
				s_state <= c_Idle_state;
				o_busy <= '0';
				s_datacount <= "00";
				s_reset <= '1';
			end if;
	---------------------------------------------------	
		When c_Write_State  =>	--2
			s_lastBusyState <= s_busy;
			if (s_busy = '0' and s_lastBusyState = '1' and s_datacount = "01") then 	--faling edge of busy and we need to write the first 8 bit
				s_addr <= s_adress(s_index_adress);									--I2C chip adress
				s_rw <= '0'; 														--set to write
				s_datacount <= "10"; 													--we write the first 8 bit of the configuration so datacount to 1 for the second 8 bit
			elsif (s_busy  = '0' and s_lastBusyState = '1' and s_datacount = "10") then --faling edge of busy and first 8 bits are alreaddy send
				s_addr <= s_adress(s_index_adress);									--I2C chip adress
				s_rw <= '0'; 														--set to write
				s_datacount <= "00"; 													--we write the second 8 bit of the configuration so reset datacount
				s_state <= c_Read_State;											--when we have written the full configuration for a channel we have to read the conversion			
				s_enable <= '0';
			elsif (s_busy = '1'and s_datacount = "00") then
				s_data_wr <= s_configuration(s_index_configuration)(15 downto 8);	--write first 8 bit of the configuration
				s_datacount <= "01";
			elsif (s_busy = '1'and s_datacount = "10") then
				s_data_wr <= s_configuration(s_index_configuration)(7 downto 0);	--write second 8 bit of the configuration
			elsif (s_busy = '0' and s_lastBusyState = '0') then

			end if;
	---------------------------------------------------			
		When c_Read_State =>	--4
			if (s_busy = '0' and s_lastBusyState = '1' and s_datacount = "00") then 	--faling edge of busy and pointer register need to be written
				s_enable <= '1';
				s_lastBusyState <= '0';
				s_addr <= s_adress(s_index_adress);									--I2C chip adress
				s_rw <= '0'; 														--set to write
				s_data_wr <= "00000000";											--write 00 to pointer register for acces to conversion register
				s_datacount <= "01"; 													--we write the pointer register so set the datacount t one
				--s_index_configuration <= s_index_configuration +1;					--we write the second 8bit of the configuration so go to the next index			
			elsif (s_busy = '1' and s_lastBusyState = '1' and s_datacount = "01") then
                s_rw <= '1'; 														--set to read
                s_enable <= '0';
			elsif (s_busy = '0' and s_lastBusyState = '1' and s_datacount = "01") then --faling edge of busy and pointer register alreddy written start reading
                s_lastBusyState <= '0';
                --s_enable <= '0';
				s_addr <= s_adress(s_index_adress);									--I2C chip adress
				--s_rw <= '1'; 														--set to read
				s_datacount <= "10";
                s_enable <= '1';
			elsif (s_busy = '0' and s_lastBusyState = '1' and s_datacount = "10") then --faling edge of busy first 8 bits are read back
                
                s_data(s_index_configuration)(15 downto 8) <= s_data_r;				-- this is the first 8 of data
				s_datacount <= "11";													-- set datacount to 3 for the second 8 bit of data
				s_lastBusyState <= '0';
                s_enable <= '0';
			elsif (s_busy = '1' and s_lastBusyState = '1' and s_datacount = "11") then --rising edge of busy 
				s_rw <= '0';														-- set to write for the next state
				s_lastBusyState <= '1';
			elsif (s_busy = '0' and s_lastBusyState = '1' and s_datacount = "11") then	--faling edge of busy
				s_data(s_index_configuration)(7 downto 0) <= s_data_r;				--this is the second 8 bit of data
				s_datacount <= "00";													--reset datacount
				s_lastBusyState <= '0';
					if s_index_configuration >= g_number_of_channels - 1 then
					s_index_configuration <= 0;
						if s_index_adress >= g_number_of_I2C_Chips -1 then
						s_index_adress <= 0;					
						s_state <= c_Idle_state;
						else
                          s_index_adress <= s_index_adress +1;
                          s_data_wr <= "00000001";
						s_state <= c_write_state;
						end if;
					else
                      s_enable <= '1';
                      s_index_configuration <= s_index_configuration + 1;
                      s_data_wr <= "00000001";
					s_state <= c_write_state;
					end if;
			elsif (s_busy = '1') then
				s_lastBusyState <= '1';
			elsif (s_busy = '0' and s_lastBusyState = '0') then
				s_lastBusyState <='0';
			end if;
		
		
		When others =>
			s_state <= c_Idle_state;
			
		end case;
		
	end if;
	
  end process;

end Behavioral;
