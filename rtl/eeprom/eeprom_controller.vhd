library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- module to interface with an SPI flash
-- in particular the SST26VF032B
-- note how the MSCK pin that is connected to the flash chip cannot be
-- mapped in a user program. Instead a module named "USRMCLK" is instantiated
-- which forwards our desired clock signal. All other SPI pins must be mapped
-- via the normal pin assignment procedure to the correct pins. 

entity eeprom_controller is
  port (
    -- clock:
    i_clk           : in std_logic;
    -- SPI interface:
    i_spi_miso      : in std_logic;
    o_spi_mosi      : out std_logic;
    o_spi_ce        : out std_logic;
    -- control interface:
    i_read_deviceid : in std_logic;
    o_done          : out std_logic := '0';
    o_deviceid      : out std_logic_vector(7 downto 0);
    o_vendorid      : out std_logic_vector(7 downto 0);
    o_devicetype    : out std_logic_vector(7 downto 0)   
    );
end eeprom_controller;





architecture behave of eeprom_controller is
  -- constant:
  constant CMD_JEDEC_ID : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(16#9F#,8));
  -- state machine type:
  type t_State is (s_Idle, s_Cmd, s_VendorId, s_DeviceType, s_DeviceId);
  -- signals:
  signal r_State : t_State := s_Idle;
  signal r_Count : natural range 0 to 7 := 0;
  signal mclk_tristate : std_logic := '0';

  
  -- start of magic incantation
  -- (see ECP5 sysCONFIG manual section 6.1.2)
  component USRMCLK
    port(
      USRMCLKI : in std_ulogic;
      USRMCLKTS : in std_ulogic
      );
  end component;
  attribute syn_noprune: boolean ;
  attribute syn_noprune of USRMCLK: component is true;
  -- end of magic incantation
  
begin
  u1: USRMCLK port map (
    USRMCLKI => i_clk,
    USRMCLKTS => mclk_tristate
    );


-- main program
  p_main : process (i_clk) is
  begin
    if rising_edge(i_clk) then
      case r_State is
        when s_Idle =>
          if i_read_deviceid = '1' then
            r_State <= s_Cmd;
            r_Count <= 0;
            o_spi_ce <= '0';
          end if;
        when s_Cmd =>
          o_spi_mosi <= CMD_JEDEC_ID(r_Count);
          r_Count <= r_Count + 1;
          if r_Count = 7 then
            r_State <= s_Idle;
            o_spi_ce <= '1';
          end if;
          
        when s_VendorId =>

        when s_DeviceType =>

        when s_DeviceId =>
          
      end case;
    end if;
    
            

  end process;

end behave;

