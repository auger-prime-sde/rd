library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- building block designed to inject boot sequence into the housekeeping spi lines
-- for now only the science adc needs this
-- reset adc:
-- 0x03 0x00 0x02
-- enable digital function
-- 0x03 0x42 0x08
-- set digital ramp on each channel
-- 0x03 0x25 0x04
-- 0x03 0x2B 0x04
-- enable high perf mode
-- 0x03 0x03 0x03
-- enable high speed mode
-- 0x03 0x02 0x40
-- 0x03 0xD5 0x18
-- 0x03 0xD7 0x0C
-- 0x03 0xDB 0x20


entity boot_sequence is
  port (
    i_clk : in std_logic;
    i_rst : in std_logic;
    i_housekeeping_clk:  in std_logic;
    i_housekeeping_ce:   in std_logic;
    i_housekeeping_mosi: in std_logic;
    o_housekeeping_clk:  out std_logic;
    o_housekeeping_ce:   out std_logic;
    o_housekeeping_mosi: out std_logic
    );
end boot_sequence;

architecture behave of boot_sequence is

  signal spi_clk : std_logic;
  constant SPI_DIV : natural := 20;
  signal spi_clk_counter : natural range 0 to SPI_DIV-1 := 0;
  
  constant c_NUMBYTES : natural := 25;
  type t_BYTESEQ is array(0 to c_NUMBYTES-1) of bit_vector(11 downto 0);
  signal c_BOOTSEQUENCE : t_BYTESEQ := (
    -- the first bit indicates if this is a transaction separatator
    -- if it is 1 then the value of the byte does not matter
    --X"100", X"003", X"000", X"002",
    --X"100", X"003", X"042", X"008",
    X"100", X"100", X"100", X"100",
    X"100", X"003", X"003", X"003",
    X"100", X"003", X"002", X"040",
    X"100", X"003", X"0D5", X"018",
    X"100", X"003", X"0D7", X"00C",
    X"100", X"003", X"0DB", X"020", X"100" );
  
  type t_State is (s_Initial, s_LowClk, s_HighClk, s_Done);
  signal r_State : t_State := s_Initial;
  signal r_ByteCount : natural range 0 to c_NUMBYTES-1 := 0;
  signal r_BitCount  : natural range 0 to 7 := 0;
  signal r_done : std_logic := '0';
  
  -- signal for the internal spi bus
  signal r_clk : std_logic := '1';
  signal r_ce  : std_logic := '1';
  signal r_mosi: std_logic;

  signal r_bitcount_test : std_logic_vector(7 downto 0);
  signal r_bytecount_test : std_logic_vector(7 downto 0);

begin
  r_bitcount_test <= std_logic_vector(to_unsigned(r_BitCount, 8));
  r_bytecount_test <= std_logic_vector(to_unsigned(r_ByteCount, 8));

  -- forward after boot is over
  o_housekeeping_clk  <= i_housekeeping_clk  when r_done = '1' else r_clk;
  o_housekeeping_ce   <= i_housekeeping_ce   when r_done = '1' else r_ce;
  o_housekeeping_mosi <= i_housekeeping_mosi when r_done = '1' else r_mosi;

  -- generate sufficiently slow clock
  process(i_clk) is
  begin
    if rising_edge(i_clk) then
      if spi_clk_counter < SPI_DIV-1 then
        spi_clk_counter <= spi_clk_counter + 1;
      else
        spi_clk_counter <= 0;
        spi_clk <= not spi_clk;
      end if;
    end if;
  end process;

  -- main process
  process(spi_clk) is
  begin
    if rising_edge(spi_clk) then

      case r_State is
        when s_Initial =>
          r_State <= s_HighClk;
          r_ce    <= '1';
          r_clk   <= '1';
        when s_HighClk =>
          r_State <= s_LowClk;
          r_clk <= '0';
          r_mosi <= to_stdulogic(c_BOOTSEQUENCE(r_ByteCount)(7-r_BitCount));
          -- set the ce line
          if r_BitCount = 0 then
            if c_BOOTSEQUENCE(r_ByteCount)(8) = '1' then
              r_ce <= '1';
            else
              r_ce <= '0';
            end if;
          end if;
          

        when s_LowClk =>
          r_State <= s_HighClk;
          r_clk <= '1';
          -- increment counters
          r_BitCount <= (r_BitCount + 1) mod 8;
          if r_BitCount = 7 then
            r_ByteCount <= (r_ByteCount + 1) mod c_NUMBYTES;
            if r_ByteCount = c_NUMBYTES - 1 then
              r_State <= s_Done;
            end if;
          end if;
          
        when s_Done =>
          r_ce   <= '1';
          r_done <= '1';
          if r_BitCount = 7 then
            if i_rst = '0' then
              r_State <= s_Initial;
              r_done <= '0';
            end if;
          else
            r_BitCount <= (r_BitCount + 1) mod 8;
          end if;
          
          
      end case;
    end if;
    
  end process;
  
  

end behave;


    
