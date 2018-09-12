library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity software_integration_tb is
end software_integration_tb;

architecture behavior of software_integration_tb is
  constant address_width : natural := 11;
  constant adc_bits : natural := 12;
  constant adc_driver_bits : natural := 14;
  constant data_clk_period : time := 5 ns;
  constant uart_clk_period : time := 50 ns; -- 20MBaud
  constant uart_word_size : natural := 7;

  signal stop : std_logic := '0';
  signal data_clk : std_logic := '0';
  signal uart_clk : std_logic := '0';

  -- interface to readout:
  signal i_start_transfer : std_logic := '0';
  signal o_transfer_done : std_logic;
  signal o_data : std_logic;

  -- interface to data writer:
  signal i_trigger : std_logic := '0';

  -- interface to ADC:
  signal i_data : std_logic_vector(25 downto 0) := (others=>'0');
  --signal left : natural range 0 to 4095 := 0;
  --signal right : natural range 0 to 4095 := 4095;
  signal counter : natural range 0 to 4096 := 0;

  component software_integration is
    generic (
      g_ADC_BITS : natural;
      g_ADC_DRIVER_BITS : natural;
      g_BUFFER_INDEXSIZE : natural;
      g_UART_WORDSIZE : natural
      );
    port (
      i_data : in std_logic_vector (2*(g_ADC_BITS+1)-1 downto 0);
      clk_intern : in std_logic;
      clk_uart : std_logic;
      trigger : in std_logic;
      i_start_transfer : in std_logic;
      o_transfer_done : out std_logic;
      o_data : out std_logic
    );
  end component;
  
begin
  dut : software_integration
    generic map (
      g_ADC_BITS => adc_bits,
      g_ADC_DRIVER_BITS => adc_driver_bits,
      g_BUFFER_INDEXSIZE => address_width,
      g_UART_WORDSIZE => uart_word_size
    )
    port map (
      i_data => i_data,
      clk_intern => data_clk,
      clk_uart => uart_clk,
      trigger => i_trigger,
      i_start_transfer => i_start_transfer,
      o_transfer_done => o_transfer_done,
      o_data => o_data
    );

  --i_data(25 downto 13) <= std_logic_vector(to_unsigned(left,13));
  --i_data(12 downto 0) <= std_logic_vector(to_unsigned(right,13));
  i_data(25 downto 0) <= std_logic_vector(to_unsigned(counter,26));
  p_data_clk : process is
  begin
    if stop = '1' then
      wait;
    end if;
    wait for data_clk_period / 2;
    --report "data clk";
    data_clk <= not data_clk;
    if data_clk = '0' then
    --  left <= (left+1) mod 4096;
    --  right <= (right-1) mod 4096;
    
      --i_data(25 downto 0) <= (others => '1');
      --i_data(25 downto 0) <= (others => '0');
      counter <= (counter + 1) mod 4096;
    end if;

  end process;
  p_uart_clk : process is
  begin
    if stop = '1' then
      wait;
    end if;
    wait for uart_clk_period / 2;
    --report "uart clk";
    uart_clk <= not uart_clk;
  end process;

  p_test : process is
  begin
    wait for 42 ns;
    i_trigger <= '1';
    wait for 42 ns;
    i_start_transfer <= '1';
    i_trigger <= '0';
    
    wait for 5 ms;
    stop <= '1';
    wait;
  end process;

end behavior;
