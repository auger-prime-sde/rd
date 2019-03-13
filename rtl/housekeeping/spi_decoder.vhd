library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- translator between spi and a parallel bus at two different clock speeds
-- it is assumed that the parallel clock is faster than the spi clock.
-- On the parallel side a flag (i_transmit) is available to indicate that the
-- data on i_data should be written to miso. The data must be present at the
-- first rising edge during which i_transmit is high. o_recv_count is available
-- for the subsystem to determine how many bits have been received. Note that
-- in typical use cases you'll have 0 clock cycles between finding the last bit
-- and writing i_transmit and i_data. This means data must be immediately
-- available or the command must be split into a fetch_ and a get_ command.
-- It is assumed that each transaction consists of 1 read phase and 1 write
-- phase of maximum length g_INPUT_BITS and g_OUTPUT_BITS respectively.

-- update: let's assume transactions occur in multiples of 32 bit words and
-- that all subsystems have i/o busses smaller than 32 bits and therefore just
-- one word in and one word out is needed.  

entity spi_decoder is
  generic (
    -- width of the parallel busses.
    -- must be multiples of wordsize. If larger than wordsize, blocks will be
    -- aligned to multiples of this. I.e. bit 0 is read/written at clock 0 and
    -- N*g_*_BITS-1. Consequently, if you wish to receive 8 bits and then
    -- transmit 16, you'll have to either 1) set g_OUTPUT_BITS to 24 and write
    -- the 16 output bits to the last 16 bits in the output bus. (bus is not
    -- latched so that should work); or 2) set g_OUTPUT_BITS to 8 and delay the
    -- writing of the last 8 bits until the first 8 have been written. 
    g_INPUT_BITS : natural := 32;
    g_OUTPUT_BITS : natural := 32
    );
  port (
    -- SPI interface:
    i_spi_clk    : in  std_logic;
    i_spi_mosi   : in  std_logic;
    o_spi_miso   : out std_logic;
    i_spi_ce     : in  std_logic;
    -- parallel interface to subsystem:
    i_clk        : in std_logic;
    o_data       : out std_logic_vector(g_INPUT_BITS-1 downto 0) := (others => 'Z');
    i_data       : in std_logic_vector(g_OUTPUT_BITS-1 downto 0);
    o_recv_count : out std_logic_vector(g_INPUT_BITS-1 downto 0) := (others => '0')
    );
end spi_decoder;

architecture behave of spi_decoder is

  signal r_read_count   : natural range 0 to g_INPUT_BITS-1 := g_INPUT_BITS-1;
  signal r_write_count  : natural range 0 to g_OUTPUT_BITS-1 := g_OUTPUT_BITS-1;

  type t_stabilizer is (s_Low, s_Delay, s_High);
  signal r_stabilizer : t_stabilizer := s_High; -- start by waiting for a low transition
  
  
begin

  p_read : process(i_spi_clk) is
  begin
    
    if rising_edge(i_spi_clk) then
      o_data(r_read_count) <= i_spi_mosi;
      if r_read_count = 0 then
        r_read_count <= g_INPUT_BITS-1;
      else
        r_read_count <= r_read_count - 1;
      end if;
    end if; -- rising_edge(i_spi_clk)
  end process;

  p_write : process(i_spi_clk) is
  begin
    if falling_edge(i_spi_clk) then
      o_spi_miso <= i_data(r_write_count);
      if r_write_count = 0 then
        r_write_count <= g_OUTPUT_BITS-1;
      else
        r_write_count <= r_write_count - 1;
      end if;
    end if; -- falling_edge(i_spi_clk)
  end process;
  

  -- the moment we 'see' a spi_clk='1' on the spi clk we may not have all data
  -- because of meta-stability. Therefore we delay the increment of the
  -- o_recv_count to the next rising edge of i_clk. It is guaranteed that the
  -- bus data is stable at that time. 
  p_recv_trig : process(i_clk) is
  begin
    if i_clk'event then
      case r_stabilizer is
        when s_Low =>
          if i_spi_clk = '1' then
            r_stabilizer <= s_Delay;
          end if;
        when s_Delay =>
          o_recv_count <= std_logic_vector(to_unsigned(g_INPUT_BITS-r_read_count-1, g_INPUT_BITS));
          r_stabilizer <= s_High;
        when s_High =>
          if i_spi_clk = '0' then
            r_stabilizer <= s_Low;
          end if;
      end case;
    end if; -- rising_edge(i_clk)
  end process;
end behave;

      
