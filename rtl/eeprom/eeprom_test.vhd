library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eeprom_test is
  port (
    i_clk           : in std_logic;
    i_eeprom_miso   : in std_logic;
    o_eeprom_ce     : out std_logic;
    o_eeprom_mosi   : out std_logic;
    o_eeprom_clk    : out std_logic;
    i_uart_data     : in std_logic;
    o_uart_data     : out std_logic
    );
end eeprom_test;


architecture behave of eeprom_test is

  signal internal_clk       : std_logic;
  signal uart_command       : std_logic_vector(7 downto 0);
  signal uart_command_valid : std_logic;
  signal eeprom_triger      : std_logic := '0';
    

  
  component eeprom_controller
    port (
      -- clock: 
      i_clk           : in std_logic;
      -- SPI interface:
      i_spi_miso      : in std_logic;
      o_spi_mosi      : out std_logic;
      o_spi_ce        : out std_logic;
      -- control interface:
      i_command       : in t_command;
      i_command_ready : in std_logic;
      o_done          : out std_logic := '0';
      o_deviceid      : out std_logic_vector(7 downto 0);
      o_vendorid      : out std_logic_vector(7 downto 0);
      o_devicetype    : out std_logic_vector(7 downto 0)   
      );
  end component;

  component clock_divider
    generic (g_MAX_COUNT : natural);
    port (
      i_clk  : in std_logic;
      o_clk  : out std_logic
      );
  end component;

  component uart_rx
    generic (g_BAUD_DIVIDER : natural);
    port (
      i_data : in std_logic;
      i_sample_clk : in std_logic;
      o_data: out std_logic_vector(7 downto 0);
      o_datavalid: out std_logic := '0'
      );
  end component;

  component uart_tx
    generic (g_WORDSIZE : natural);
    port (
      i_data      : in std_logic_vector(g_WORDSIZE-1 downto 0);
      i_dataready : in std_logic;
      i_clk       : in std_logic;
      o_data      : out std_logic := '1';
      o_ready     : out std_logic := '1'
      );
  end component;


begin
  o_eeprom_clk <= internal_clk;

  clock_divider_1 : clock_divider
    generic map (g_MAX_COUNT => 40)
    port map (
      i_clk => i_clk,
      o_clk => internal_clk
      );

  uart_rx_1 : uart_rx
    generic map (g_BAUD_DIVIDER => 40)
    port map (
      i_data       => i_uart_data,
      i_sample_clk => i_clk,
      o_data       => uart_command,
      o_datavalid  => uart_command_valid
      );

  uart_tx_1 : uart_tx
    generic map (g_WORDSIZE => 8)
    port map (
      i_data      => std_logic_vector(to_unsigned(52, 8)),
      i_dataready => '0',
      i_clk       => internal_clk,
      o_data      => o_uart_data,
      o_ready     => open
      );
    
  eeprom_controller_1 : eeprom_controller
    port map (
      i_clk           => internal_clk,
      i_spi_miso      => i_eeprom_miso,
      o_spi_mosi      => o_eeprom_mosi,
      o_spi_ce        => o_eeprom_ce,
      i_read_deviceid => eeprom_triger,
      o_done          => open,
      o_deviceid      => open,
      o_vendorid      => open,
      o_devicetype    => open
      );

  -- test process
  p_test : process (internal_clk) is
  begin
    if rising_edge(internal_clk) then
      eeprom_triger <= '0';
      if uart_command_valid = '1' then
        if unsigned(uart_command) = 101 then -- 101 is ascii 'e'
          eeprom_triger <= '1';
        end if;
      end if;
      
    end if;
  end process;
  


end behave;

  
