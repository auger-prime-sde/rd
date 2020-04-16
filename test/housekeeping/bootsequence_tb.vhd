library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

entity bootsequence_tb is
end bootsequence_tb;

architecture behave of bootsequence_tb is
  constant clk_period : time := 250 ns; -- 4 MHz

  constant random1 : std_logic_vector(0 to 103) := "01111110000000110010101100101011110001100110101010011101101000110111101001010111011110110000001000100000";
  constant random2 : std_logic_vector(0 to 103) :="00111000101101010101100000001000111010101011110000100100001001110111001010100010001111010100001011011001";
  constant random3 : std_logic_vector(0 to 103) :="01000000010110000011101100010110000110011110100100110100010110010111011000001011011011001100111000110110";
  
  signal i_clk     : std_logic;
  signal i_rst     : std_logic := '0';
  signal i_hk_clk  : std_logic;
  signal i_hk_ce   : std_logic;
  signal i_hk_mosi : std_logic;
  signal o_hk_clk  : std_logic;
  signal o_hk_ce   : std_logic;
  signal o_hk_mosi : std_logic;

  
  signal stop : std_logic := '0';

  constant c_NUMBYTES : natural := 36;
  type t_BYTESEQ is array(0 to c_NUMBYTES-1) of bit_vector(7 downto 0);
  constant c_BOOTSEQUENCE : t_BYTESEQ := (
    X"03", X"00", X"02",
    X"03", X"29", X"00",
    X"03", X"41", X"00",
    X"03", X"03", X"03",
    X"03", X"F2", X"00",
    X"03", X"EF", X"00",
    X"03", X"41", X"00",
    X"03", X"02", X"40",
    X"03", X"D5", X"18",
    X"03", X"D7", X"0C",
    X"03", X"DB", X"20",
    X"08", X"04", X"00");

  
  component bootsequence is
    port (
      i_clk    : in  std_logic;
      i_rst    : in  std_logic;
      i_hk_clk  : in std_logic;
      i_hk_ce   : in std_logic;
      i_hk_mosi : in std_logic;
      o_hk_clk : out std_logic;
      o_hk_ce  : out std_logic;
      o_hk_mosi : out std_logic
      );
  end component;

begin

  dut : bootsequence
    port map (
      i_clk    => i_clk,
      i_rst    => i_rst,
      i_hk_clk => i_hk_clk,
      i_hk_ce  => i_hk_ce,
      i_hk_mosi=> i_hk_mosi,
      o_hk_clk => o_hk_clk,
      o_hk_ce  => o_hk_ce,
      o_hk_mosi=> o_hk_mosi);


  p_clk : process is
  begin
    -- Finish simulation when stop is asserted
    if stop = '1' then
      wait;
    end if;
    i_clk <= '0';
    wait for clk_period / 2;
    i_clk <= '1';
    wait for clk_period / 2;
  end process;

  -- none of this should matter because input during boot should be blocked
  p_bg : process is
  begin
    wait for 52 ns;
    for x in 0 to 250 loop
      for i in 0 to 100 loop
        i_hk_clk  <= random1(i);
        i_hk_ce   <= random2(i);
        i_hk_mosi <= random3(i);
        wait for clk_period;
      end loop;
    end loop;
    i_hk_clk <= 'U';
    i_hk_ce <= 'U';
    i_hk_mosi <= 'U';
    wait;
  end process;
  
  -- actual test process
  p_test : process is
  begin
    for i in 0 to 11 loop
      wait until o_hk_ce = '0';
      for bit in 7 downto 0 loop
        assert o_hk_mosi = to_stdulogic(c_BOOTSEQUENCE(3*i+0)(bit)) report "bad initialization code, expected " & std_logic'image(to_stdulogic(c_BOOTSEQUENCE(3*i+0)(bit))) & " but got " & std_logic'image(o_hk_mosi);

        assert o_hk_ce = '0' report "CE lines toggled mid-word";
        wait until o_hk_clk = '0';
        wait until o_hk_clk = '1';
      end loop;
      for bit in 7 downto 0 loop
        assert o_hk_mosi = to_stdulogic(c_BOOTSEQUENCE(3*i+1)(bit)) report "bad initialization code, expected " & std_logic'image(to_stdulogic(c_BOOTSEQUENCE(3*i+1)(bit))) & " but got " & std_logic'image(o_hk_mosi);
        assert o_hk_ce = '0' report "CE lines toggled mid-word";
        wait until o_hk_clk = '0';
        wait until o_hk_clk = '1';
      end loop;
      for bit in 7 downto 0 loop
        assert o_hk_mosi = to_stdulogic(c_BOOTSEQUENCE(3*i+2)(bit)) report "bad initialization code, expected " & std_logic'image(to_stdulogic(c_BOOTSEQUENCE(3*i+2)(bit))) & " but got " & std_logic'image(o_hk_mosi);
        assert o_hk_ce = '0' report "CE lines toggled mid-word";
        wait until o_hk_clk = '0';
        wait until o_hk_clk = '1';
      end loop;
      wait for clk_period;
      assert o_hk_ce = '1' report "more data received than expected";
    end loop;

    -- wait until the last buffer byte is sent
    wait for 16*clk_period*20;

    -- test if data comes through transparent after boot:
    for i in 0 to 100 loop
      -- wait for rising edge
      wait until i_clk = '0';
      wait until i_clk = '1';
      wait for 1 ns;
      assert o_hk_clk  = i_hk_clk  report "clock not forwarded after boot is over";
      assert o_hk_mosi = i_hk_mosi report "mosi not forwarded after boot is over";
      assert o_hk_ce   = i_hk_ce   report "ce not forwarded after boot is over";
    end loop;
    
    
    stop <= '1';
    wait;
  end process;
  
  

end behave;

      
