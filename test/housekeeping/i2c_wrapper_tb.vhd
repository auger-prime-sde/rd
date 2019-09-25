library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.common.all;

entity i2c_wrapper_tb is
end i2c_wrapper_tb;

-- TODO: is the trigger pulse always long enough
-- TODO: check all clock domain crossings

architecture behave of i2c_wrapper_tb is
  constant clk_period : time := 10 ns;
  constant spi_period : time := 371 ns;

  signal stop : std_logic := '0';

  signal i_hk_fast_clk : std_logic := '0';
  signal i_trigger : std_logic := '0';
  signal i_spi_clk : std_logic := '0';
  signal i_spi_mosi : std_logic := '0';
  signal o_spi_miso : std_logic;
  signal i_dev_select : std_logic_vector(7 downto 0);
  signal io_hk_sda : std_logic := 'Z';
  signal io_hk_scl : std_logic;

  signal r_count : std_logic_vector(7 downto 0) := "00000000";
  signal r_test  : std_logic_vector(15 downto 0) := "1010111101101000";
                                                   
  constant c_testdata : t_i2c_data := (
    -- write address:
    (data => "01100010", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
    -- write register (0xC0, i.e. chip id and rev):
    (data => "11000000", restart => '0', dir => '0', ack=>'X', addr => "XXX"),
    -- write address again and restart:
    (data => "01100011", restart => '1', dir => '0', ack=>'X', addr => "XXX"),
    -- read value of that reg, transmit NACK and save data at 001:
    (data => "XXXXXXXX", restart => '0', dir => '1', ack=>'1', addr => "001")  );
  
  
  component i2c_wrapper is
    generic (
       g_SUBSYSTEM_ADDR : std_logic_vector;
       g_SEQ_DATA : t_i2c_data
      );
    port (
      -- clock
      i_hk_fast_clk : in std_logic;
      -- trigger
      i_trigger     : in std_logic;
      -- spi interface
      i_spi_clk     : in std_logic;
      i_spi_mosi    : in std_logic;
      o_spi_miso    : out std_logic;
      i_dev_select  : in std_logic_vector(g_SUBSYSTEM_ADDR'length-1 downto 0);
      -- i2c interface
      io_hk_sda     : inout std_logic;
      io_hk_scl     : inout std_logic
      );
  end component;

begin
  dut : i2c_wrapper
    generic map (
      g_SUBSYSTEM_ADDR => "00000100",
      g_SEQ_DATA => c_testdata
      )
    port map (
      i_hk_fast_clk => i_hk_fast_clk,
      i_trigger => i_trigger,
      i_spi_clk => i_spi_clk,
      i_spi_mosi => i_spi_mosi,
      o_spi_miso => o_spi_miso,
      i_dev_select => i_dev_select,
      io_hk_sda => io_hk_sda,
      io_hk_scl => io_hk_scl
      );

  p_hk_clk : process is
  begin
    if stop = '1' then
      wait;
    end if;
    i_hk_fast_clk <= '0';
    wait for clk_period / 2;
    i_hk_fast_clk <= '1';
    wait for clk_period / 2;
  end process;

  p_trig : process is
  begin
    wait for 100 ns;
    i_trigger <= '1';
    wait for 1000 ns;
    i_trigger <= '0';
    
    -- data should now be present in buffer
    --wait for 600000 ns;

    --stop <= '1';
    wait;
  end process;

  p_test : process is
  begin
    i_spi_clk <= '1';
    i_spi_mosi <= '1';
    i_dev_select <= "00000000";

    for word in 0 to 1 loop
      -- wait for 8 rising edges
      for i in 7 downto 0 loop
        wait until io_hk_scl = '0';
        wait until io_hk_scl /= '0';
        if c_testdata(word).data(i) = '1' then
          assert io_hk_sda /= '0' report "wrong data bit";
        else
          assert io_hk_sda = '0' report "wrong data bit";
        end if;
      end loop;
      -- at the next falling edge assert ack low
      wait until io_hk_scl = '0';
      io_hk_sda <= '0';
      wait until io_hk_scl /= '0';
      io_hk_sda <= 'Z';
    end loop;

    -- wait for a falling edge on sda and assert restart condition
    wait until io_hk_sda /= '0';
    wait until io_hk_sda = '0';
    assert io_hk_scl /= '0';

    -- transmit again
    for i in 7 downto 0 loop
      wait until io_hk_scl = '0';
      wait until io_hk_scl /= '0';
      if c_testdata(2).data(i) = '1' then
        assert io_hk_sda /= '0' report "wrong data bit";
      else
        assert io_hk_sda = '0' report "wrong data bit";
      end if;
    end loop;
    -- write ack again
    wait until io_hk_scl = '0';
    io_hk_sda <= '0';
    wait until io_hk_scl /= '0';
    io_hk_sda <= 'Z';
    
    -- the last word is a read word:
    for i in 7 downto 0 loop
      wait until io_hk_scl = '0';
      if c_testdata(0).data(i) = '1' then -- we abuse the address as data
        io_hk_sda <= 'Z';
      else
        io_hk_sda <= '0';
      end if;
      wait until io_hk_scl /= '0';
    end loop;
    io_hk_sda <= 'Z';
    -- READ ack
    wait until io_hk_scl = '0';
    wait until io_hk_scl /= '0';
    --report "asserting ack at time " & time'image(now);
    assert io_hk_sda /= '0' report "wrong ack bit";

    -- consume one more rising edge
    wait until io_hk_scl = '0';
    wait until io_hk_scl /= '0';


    
    -- wait some time
    wait for 50 us;
    


    i_dev_select <= "00000100";
    r_count <= "00000001";
    wait for spi_period / 2;

    -- send spi message
    for i in 0 to 7 loop
      i_spi_clk <= '0';
      i_spi_mosi <= r_count(7-i);
      wait for spi_period / 2;
      i_spi_clk <= '1';
      wait for spi_period / 2;
    end loop;

    -- read spi reply
    for i in 0 to 7 loop
      i_spi_clk <= '0';
      wait for spi_period / 2;
      i_spi_clk <= '1';
      wait for spi_period / 2;
    end loop;

    i_dev_select <= "00000000";

    wait for 10 us;
    
    stop <= '1';
    wait;
  end process;
  
end behave;

  
  
  
