library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- translator between spi and a parallel bus at two different clock
-- speeds. It is assumed that the parallel clock is at least twice
-- faster than the spi clock.  On the parallel side a counter
-- (o_recv_count) is available to indicate how many bits have been
-- received. When this counter overflows to 0 the last word is
-- available in full at the bus. This is not latched so the contents
-- on the bus must be captured at that clock transition. Reading and
-- writing happens in parallel but the input and output widths do not
-- have to be identical. Technically there are no further constraints
-- on the bus widths but in practice we will likely have to use
-- multiples of 32 bits to fit the buswidth at the UUB side. The data
-- must be present at the falling edge of the spi clock. This is
-- guaranteed if the subsystem writes its data to the output bus on
-- the rising edge of the fast clock at which the desired value of
-- o_recv_count is first seen (usually 0). This means the subsystem
-- has no further clock cycles available for processing the request
-- and must immediately respond. This can be alleviated by defining a
-- wider input bus than needed and using the remaining clock cycles to
-- come up with the appropriate response. E.g. by processing the
-- request when o_recv_count=30, at least 8 clock cycles can be used
-- before the response must be written (at
-- o_recv_count=0). Alternatively the request could be split in a
-- fetch, a poll and a get command spread over multiple
-- transactions. Notable difference to earlier design: there is no
-- ready line back to the controller. This functionality must be
-- implemented as an spi command if needed.



entity spi_decoder is
  generic (
    -- width of the parallel busses.  Take care if not identical: If
    -- you wish to receive 8 bits and then transmit 16, you'll have to
    -- either 1) set g_OUTPUT_BITS to 24 and write the 16 output bits
    -- to the last 16 bits in the output bus. (bus is not latched so
    -- that should work); or 2) set g_OUTPUT_BITS to 8 and delay the
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
    --if rising_edge(i_clk) then
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
    end if; -- i_clk'event
  end process;
end behave;

      
