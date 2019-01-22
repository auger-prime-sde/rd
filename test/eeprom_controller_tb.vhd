library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_arith.all;
  
entity eeprom_controller_tb is
end eeprom_controller_tb;



  
architecture behave of eeprom_controller_tb is
  constant clk_period : time := 10 ns;
  signal stop : std_logic := '0';
  signal i_clk : std_logic := '0';
  signal i_spi_miso, o_spi_mosi, o_spi_ce : std_logic;
  signal i_read_deviceid : std_logic := '0';
  signal o_done : std_logic;
  signal o_deviceid, o_vendorid, o_devicetype : std_logic_vector(7 downto 0);
  

  constant addr       : bit_vector(7 downto 0) := X"9F";
  constant vendorid   : bit_vector(7 downto 0) := X"BF";
  constant devicetype : bit_vector(7 downto 0) := X"26";
  constant deviceid   : bit_vector(7 downto 0) := X"42";
  
  component eeprom_controller is
    port (
      -- clock:
      i_clk           : in std_logic;
      -- SPI interface:
      i_spi_miso      : in std_logic;
      o_spi_mosi      : out std_logic := '0';
      o_spi_ce        : out std_logic := '1';
      -- control interface:
      i_command_ready : in std_logic;
      o_done          : out std_logic := '0';
      o_deviceid      : out std_logic_vector(7 downto 0);
      o_vendorid      : out std_logic_vector(7 downto 0);
      o_devicetype    : out std_logic_vector(7 downto 0)
      );
  end component;
  
begin
  dut : eeprom_controller
    port map (
      i_clk           => i_clk,
      i_spi_miso      => i_spi_miso,
      o_spi_mosi      => o_spi_mosi,
      o_spi_ce        => o_spi_ce,
      i_command_ready => i_read_deviceid,
      o_done          => o_done,
      o_deviceid      => o_deviceid,
      o_vendorid      => o_vendorid,
      o_devicetype    => o_devicetype
      );

  p_clk : process is
  begin
    if stop = '1' then
      wait;
    end if;

    i_clk <= not i_clk;
    wait for clk_period /2;
  end process;

  p_test : process is
  begin
    -- initial wait for a bit:
    wait for 50 ns;
    -- pulse read trigger:
    i_read_deviceid <= '1';
    wait for 10 ns;
    i_read_deviceid <= '0';
    
    -- wait for spi to begin
    wait until o_spi_ce = '0';
    
    -- check for 8 bits at rising edges
    for i in 0 to 7 loop
      wait until rising_edge(i_clk);
      assert to_bit(o_spi_mosi) = addr(7-i) report "addr mismatch" severity warning;
    end loop;

    -- write vendor id's back
    for i in 0 to 7 loop
      wait until falling_edge(i_clk);
      -- the following is unfortunately not implemented
      --i_spi_miso <= to_std_logic(vendorid(7-i));
      if vendorid(7-i)='1' then
        i_spi_miso <= '1';
      else
        i_spi_miso <= '0';
      end if;
    end loop;
    -- write device type's back
    for i in 0 to 7 loop
      wait until falling_edge(i_clk);
      -- the following is unfortunately not implemented
      --i_spi_miso <= to_std_logic(vendorid(7-i));
      if devicetype(7-i)='1' then
        i_spi_miso <= '1';
      else
        i_spi_miso <= '0';
      end if;
    end loop;
    -- write device id's back
    for i in 0 to 7 loop
      wait until falling_edge(i_clk);
      -- the following is unfortunately not implemented
      --i_spi_miso <= to_std_logic(vendorid(7-i));
      if deviceid(7-i)='1' then
        i_spi_miso <= '1';
      else
        i_spi_miso <= '0';
      end if;
    end loop;

    wait until o_spi_ce = '1';
    assert o_vendorid   = to_stdlogicvector(vendorid)   report "vendorid not recovered";
    assert o_devicetype = to_stdlogicvector(devicetype) report "devicetype not recovered";
    assert o_deviceid   = to_stdlogicvector(deviceid)   report "deviceid not recovered";
    

    -- some idle time at the end
    wait for 10*clk_period;
    stop <= '1';
    wait;
  end process;

end behave;
