library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_tb is
end top_tb;

architecture behavior of top_tb is
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
  signal i_data : std_logic_vector(13 downto 0) := (others=>'0');
  signal i_data_ov : std_logic := '0'; -- what is this? overflow bit?
  signal i_rst : std_logic := '0';

  component top is
    generic (
      g_ADC_BITS : natural;
      g_ADC_DRIVER_BITS : natural;
      g_BUFFER_INDEXSIZE : natural;
      g_UART_WORDSIZE : natural
      );
    port (
      dataIn : in std_logic_vector (g_ADC_DRIVER_BITS-1 downto 0);
      dataOvIn : in std_logic;
      clk : in std_logic;
      clk_uart : std_logic;
      rst : in std_logic;
      trigger : in std_logic;
      i_start_transfer : in std_logic;
      o_data : out std_logic
    );
  end component;
  
begin
  dut : top
    generic map (
      g_ADC_BITS => adc_bits,
      g_ADC_DRIVER_BITS => adc_driver_bits,
      g_BUFFER_INDEXSIZE => address_width,
      g_UART_WORDSIZE => uart_word_size
    )
    port map (
      dataIn => i_data,
      dataOvIn => i_data_ov,
      clk => data_clk,
      clk_uart => uart_clk,
      rst => i_rst,
      trigger => i_trigger,
      i_start_transfer => i_start_transfer,
      o_data => o_data
    );

  p_data_clk : process is
  begin
    if stop = '1' then
      wait;
    end if;
    wait for data_clk_period / 2;
    report "data clk";
    data_clk <= not data_clk;
  end process;
  p_uart_clk : process is
  begin
    if stop = '1' then
      wait;
    end if;
    wait for uart_clk_period / 2;
        report "uart clk";
    uart_clk <= not uart_clk;
  end process;

  p_test : process is
  begin
    wait for 52 ns;
    i_trigger <= '1';
    wait for 1 us;
    stop <= '1';
    wait;
  end process;

end behavior;
