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


entity bootsequence is
  generic (
    g_DIV : natural := 20 -- 100 MHz down to 5 MHz
    );
  port (
    i_clk     : in std_logic;
    i_rst     : in std_logic;
    i_hk_clk  : in std_logic;
    i_hk_ce   : in std_logic;
    i_hk_mosi : in std_logic;
    o_hk_clk  : out std_logic;
    o_hk_ce   : out std_logic;
    o_hk_mosi : out std_logic
    );
end bootsequence;

architecture behave of bootsequence is

  --signal spi_clk : std_logic;
  --constant SPI_DIV : natural := 20;
  --signal spi_clk_counter : natural range 0 to SPI_DIV-1 := 0;
  
  constant c_NUMBYTES : natural := 53;
  type t_BYTESEQ is array(0 to c_NUMBYTES-1) of bit_vector(11 downto 0);
  signal c_BOOTSEQUENCE : t_BYTESEQ := (
    -- the first bit indicates if this is a transaction separatator
    -- if it is 1 then the value of the byte does not matter
    -- after a reboot 1ns is needed. at 2MHz each clock cycle already lasts
    -- 500ns but we wait 1 byte (8 clock cycles) anyway.
    -- after each register write 10 ns is enough. Again we wait 8 clock cycles.
    -- just a bit of waiting for the ADC to boot:
    X"100", X"100", X"100", X"100",
    -- software reset
    X"100", X"003", X"000", X"002",
    -- re-apply what should already be the default
    X"100", X"003", X"029", X"000",
    X"100", X"003", X"041", X"000",
    -- enable checker-board
    --X"100", X"042", X"008",
    --X"100", X"025", X"003",
    --X"100", X"02B", X"003",
    -- enable high performance mode:
    X"100", X"003", X"003", X"003",
    -- disable low speed mode, should already by off:
    X"100", X"003", X"0F2", X"000",
    X"100", X"003", X"0EF", X"000",
    -- cmos mode off, should already be off:
    X"100", X"003", X"041", X"000",
    -- high performance mode
    X"100", X"003", X"002", X"040",
    X"100", X"003", X"0D5", X"018",
    X"100", X"003", X"0D7", X"00C",
    X"100", X"003", X"0DB", X"020",
    -- set default start offset 1024 (0x0400)
    X"100", X"008", X"004", X"000",
    X"100" );

  attribute syn_romstyle : string;
  attribute syn_romstyle of c_BOOTSEQUENCE : signal is "logic";
  
  type t_State is (s_Initial, s_LowClk, s_HighClk, s_Done);
  signal r_State : t_State := s_Initial;
  signal r_ByteCount : natural range 0 to c_NUMBYTES-1 := 0;
  signal r_BitCount  : natural range 0 to 7 := 0;
  signal r_done : std_logic := '0';
  signal r_count : natural range 0 to g_DIV-1 := 0;


  -- signal r_boot_ce   : std_logic;
  -- signal r_boot_clk  : std_logic;
  -- signal r_boot_mosi : std_logic;
  
  signal r_bitcount_test : std_logic_vector(7 downto 0);
  signal r_bytecount_test : std_logic_vector(7 downto 0);

begin
  r_bitcount_test <= std_logic_vector(to_unsigned(r_BitCount, 8));
  r_bytecount_test <= std_logic_vector(to_unsigned(r_ByteCount, 8));

  -- o_hk_ce   <= i_hk_ce   when r_done = '1' else r_boot_ce;
  -- o_hk_clk  <= i_hk_clk  when r_done = '1' else r_boot_clk;
  -- o_hk_mosi <= i_hk_mosi when r_done = '1' else r_boot_mosi;

  
  -- main process
  process(i_clk) is
  begin
    if rising_edge(i_clk) then
      r_count <= (r_count + 1) mod g_DIV;
      if r_count = g_DIV-1 then
        case r_State is
          when s_Initial =>
            r_State <= s_HighClk;
            o_hk_ce  <= '1';
            o_hk_clk <= '1';
          when s_HighClk =>
            r_State <= s_LowClk;
            o_hk_clk <= '0';
            o_hk_mosi <= to_stdulogic(c_BOOTSEQUENCE(r_ByteCount)(7-r_BitCount));
            -- set the ce line
            if r_BitCount = 0 then
              if c_BOOTSEQUENCE(r_ByteCount)(8) = '1' then
                o_hk_ce <= '1';
              else
                o_hk_ce <= '0';
              end if;
            end if;
          
          when s_LowClk =>
            r_State <= s_HighClk;
            o_hk_clk <= '1';
            -- increment counters
            r_BitCount <= (r_BitCount + 1) mod 8;
            if r_BitCount = 7 then
              r_ByteCount <= (r_ByteCount + 1) mod c_NUMBYTES;
              if r_ByteCount = c_NUMBYTES - 1 then
                r_State <= s_Done;
              end if;
            end if;
          when s_Done =>
            -- case is handled at faster clock code below
        end case;
      end if;
      
          
      if r_state = s_Done then
        o_hk_ce   <= i_hk_ce;
        o_hk_clk  <= i_hk_clk;
        o_hk_mosi <= i_hk_mosi;
          
        r_done <= '1';
        if r_BitCount = 7 then
          if i_rst = '1' then
            r_State <= s_Initial;
            r_done <= '0';
          end if;
        else
          r_BitCount <= (r_BitCount + 1) mod 8;
        end if;
      end if;
    end if;
    
  end process;
  
  

end behave;


    
