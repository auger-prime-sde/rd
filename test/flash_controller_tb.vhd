library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_arith.all;
use IEEE.numeric_std.all;

entity flash_controller_tb is
end flash_controller_tb;



  
architecture behave of flash_controller_tb is
  constant clk_period : time := 10 ns;
  signal stop : std_logic := '0';
  signal i_clk : std_logic := '0';
  signal i_flash_miso, o_flash_mosi, o_flash_ce : std_logic;
  signal i_enable : std_logic := '0';

  signal i_command : std_logic_vector(3 downto 0)  := std_logic_vector(to_unsigned(1, 4));
  signal i_address : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(0, 12));
  signal i_data    : std_logic_vector(9 downto 0)  := (others=>'0');
  signal o_busy    : std_logic;
  signal o_data    : std_logic_vector(23 downto 0);

  constant addr       : bit_vector(7 downto 0) := X"9F";
  constant vendorid   : bit_vector(7 downto 0) := X"BF";
  constant devicetype : bit_vector(7 downto 0) := X"26";
  constant deviceid   : bit_vector(7 downto 0) := X"42";
  
  component flash_controller is
    port (
      -- clock:
      i_clk           : in std_logic;
      -- SPI interface:
      i_flash_miso    : in std_logic;
      o_flash_mosi    : out std_logic := '0';
      o_flash_ce      : out std_logic := '1';
      -- control interface:
      i_enable        : in std_logic;
      i_command       : in std_logic_vector(3 downto 0);
      i_address       : in std_logic_vector(11 downto 0);
      i_data          : in std_logic_vector(9 downto 0);
      o_busy          : out std_logic := '1';
      o_data          : out std_logic_vector(23 downto 0) := (others=>'Z')
      );
  end component;
  
begin
  dut : flash_controller
    port map (
      i_clk           => i_clk,
      i_flash_miso    => i_flash_miso,
      o_flash_mosi    => o_flash_mosi,
      o_flash_ce      => o_flash_ce,
      i_enable        => i_enable,
      i_command       => i_command,
      i_address       => i_address,
      i_data          => i_data,
      o_busy          => o_busy,
      o_data          => o_data
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
    i_enable <= '1';
    wait for 20 ns;
    i_enable <= '0';
    
    -- wait for spi to begin
    report "not waiting for ce";
    --wait until o_flash_ce = '0';
    --report "ce low received";
    
    -- check for 8 bits at rising edges
    for i in 0 to 7 loop
      wait until rising_edge(i_clk);
      assert to_bit(o_flash_mosi) = addr(7-i) report "addr mismatch" severity warning;
    end loop;

    -- write vendor id's back
    for i in 0 to 7 loop
      wait until falling_edge(i_clk);
      if vendorid(7-i)='1' then
        i_flash_miso <= '1';
      else
        i_flash_miso <= '0';
      end if;
    end loop;
    -- write device type's back
    for i in 0 to 7 loop
      wait until falling_edge(i_clk);
      if devicetype(7-i)='1' then
        i_flash_miso <= '1';
      else
        i_flash_miso <= '0';
      end if;
    end loop;
    -- write device id's back
    for i in 0 to 7 loop
      wait until falling_edge(i_clk);
      if deviceid(7-i)='1' then
        i_flash_miso <= '1';
      else
        i_flash_miso <= '0';
      end if;
    end loop;

    wait until o_flash_ce = '1';
    assert o_data( 7 downto  0) = to_stdlogicvector(vendorid)   report "vendorid not recovered";
    assert o_data(15 downto  8) = to_stdlogicvector(devicetype) report "devicetype not recovered";
    assert o_data(23 downto 16) = to_stdlogicvector(deviceid)   report "deviceid not recovered";
    

    -- some idle time at the end
    wait for 10*clk_period;
    stop <= '1';
    wait;
  end process;

end behave;
