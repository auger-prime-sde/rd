library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity digitaloutput_tb is
end  digitaloutput_tb;

architecture behavior of digitaloutput_tb is

  constant clk_period : time := 20 ns;
  constant spi_period : time := 151 ns;

  constant c_DEFAULT : std_logic_vector(7 downto 0) := "11001001";
  
  signal clk, stop : std_logic := '0';
  signal i_spi_clk : std_logic := '1';
  signal i_spi_mosi : std_logic;
  signal o_spi_miso : std_logic;
  signal i_dev_select : std_logic_vector(7 downto 0);
  signal o_data : std_logic_vector(c_DEFAULT'length-1 downto 0);


  signal test_cmd  : std_logic_vector(7 downto 0);
  signal test_data : std_logic_vector(7 downto 0);
  signal prev_data : std_logic_vector(7 downto 0);
  
  component digitaloutput is  --begin
    generic (
      g_SUBSYSTEM_ADDR : std_logic_vector;
      g_DEFAULT_OUTPUT : std_logic_vector (7 downto 0) := "11111111" 
      );
    port (
      i_clk        : in std_logic;
      i_spi_clk    : in std_logic;
      i_spi_mosi   : in std_logic;
      o_spi_miso   : out std_logic;
      i_dev_select : in std_logic_vector(g_SUBSYSTEM_ADDR'length-1 downto 0);
      o_data       : out std_logic_vector (g_DEFAULT_OUTPUT'length-1 downto 0) := g_DEFAULT_OUTPUT
      );  
  end component;
 
begin
  -- DUT instantiation
  dut : digitaloutput
    generic map (
      g_SUBSYSTEM_ADDR => "00000011",
      g_DEFAULT_OUTPUT => c_DEFAULT
      )
    port map(
      i_clk   		=> clk,
      i_spi_clk     => i_spi_clk,
      i_spi_mosi    => i_spi_mosi,
      o_spi_miso    => o_spi_miso,
      i_dev_select  => i_dev_select,
      o_data        => o_data
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
    assert o_data = c_DEFAULT report "data not initialized to default value";
    wait for 40 ns;

    -- test a write
    i_dev_select <= "00000011";
    test_cmd <= "00000001";
    test_data <= "10101010";
    wait for spi_period;
    for i in 0 to 7 loop
      i_spi_clk <= '0';
      i_spi_mosi <= test_cmd(7 - i);
      wait for spi_period / 2;
      i_spi_clk <= '1';
      wait for spi_period / 2;
    end loop;
    for i in 0 to 7 loop
      i_spi_clk <= '0';
      i_spi_mosi <= test_data(7 - i);
      wait for spi_period / 2;
      i_spi_clk <= '1';
      wait for spi_period / 2;
    end loop;
    assert o_data = test_data report "write failed";
    i_dev_select <= "00000000";
    
    wait for 0.5 us;

    i_dev_select <= "00000011";
    test_cmd <= "00000100";
    test_data <= "XXXXXXXX";
    wait for spi_period;
    for i in 0 to 7 loop
      i_spi_clk <= '0';
      i_spi_mosi <= test_cmd(7 - i);
      wait for spi_period / 2;
      i_spi_clk <= '1';
      wait for spi_period / 2;
    end loop;
    for i in 0 to 7 loop
      i_spi_clk <= '0';
      i_spi_mosi <= test_data(7 - i);
      wait for spi_period / 2;
      i_spi_clk <= '1';
      wait for spi_period / 2;
    end loop;
    assert o_data = c_DEFAULT report "reset to default failed";
    i_dev_select <= "00000000";

    wait for 0.5 us;

    -- selective bit clear
    i_dev_select <= "00000011";
    test_cmd <= "00000011";
    test_data <= "00001111";
    prev_data <= o_data;
    wait for spi_period;
    for i in 0 to 7 loop
      i_spi_clk <= '0';
      i_spi_mosi <= test_cmd(7 - i);
      wait for spi_period / 2;
      i_spi_clk <= '1';
      wait for spi_period / 2;
    end loop;
    for i in 0 to 7 loop
      i_spi_clk <= '0';
      i_spi_mosi <= test_data(7 - i);
      wait for spi_period / 2;
      i_spi_clk <= '1';
      wait for spi_period / 2;
    end loop;
    assert o_data = (prev_data and (not test_data)) report "selective bit clear failed";
    i_dev_select <= "00000000";

    wait for 0.5 us;

    -- selective bit set
    i_dev_select <= "00000011";
    test_cmd <= "00000010";
    test_data <= "01010000";
    prev_data <= o_data;
    wait for spi_period;
    for i in 0 to 7 loop
      i_spi_clk <= '0';
      i_spi_mosi <= test_cmd(7 - i);
      wait for spi_period / 2;
      i_spi_clk <= '1';
      wait for spi_period / 2;
    end loop;
    for i in 0 to 7 loop
      i_spi_clk <= '0';
      i_spi_mosi <= test_data(7 - i);
      wait for spi_period / 2;
      i_spi_clk <= '1';
      wait for spi_period / 2;
    end loop;
    assert o_data = (prev_data or test_data) report "selective bit set failed";
    i_dev_select <= "00000000";

    wait for 0.5 us;

    stop <= '1';
    wait;
  end process;
  
end behavior;
