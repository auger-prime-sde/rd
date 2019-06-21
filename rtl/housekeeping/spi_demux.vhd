library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_demux is
  generic (
    -- how many device select bits to 'cut' from the start of each transaction
    g_DEV_SELECT_BITS : natural := 8
    );
  port (
    -- SPI interface to UUB:
    i_spi_clk    : in  std_logic;
    i_hk_fast_clk: in  std_logic;
    i_spi_mosi   : in  std_logic;
    i_spi_ce     : in  std_logic;
    o_spi_clk    : out std_logic := '1';
    o_spi_mosi   : out std_logic;
    o_dev_select : out std_logic_vector(g_DEV_SELECT_BITS-1 downto 0) := (others => '0')
    );
end spi_demux;

architecture behave of spi_demux is

  type t_state is (s_Idle, s_Addr, s_Data, s_Cleanup);
  signal r_state : t_state := s_Idle;
  -- register to remember clk and ce. initial values carefull chosen such that
  -- the first sample never looks like a rising/falling edge resp.
  signal r_ce_prev : std_logic := '0';
  signal r_clk_prev : std_logic := '1';
  signal r_count : natural range 0 to g_DEV_SELECT_BITS-1 := 0;
  signal r_dev   : std_logic_vector(g_DEV_SELECT_BITS-1 downto 0) := (others => '0');
                                       
  -- only for debugging:
  signal r_count_t : std_logic_vector(3 downto 0);
  
begin
  -- for debugging
  r_count_t <= std_logic_vector(to_unsigned(r_count, 4));

  o_spi_clk <= r_clk_prev;

  p_main : process(i_hk_fast_clk) is
  begin
    if rising_edge(i_hk_fast_clk) then
      -- latch old values for edge detection
      r_clk_prev <= i_spi_clk;
      r_ce_prev  <= i_spi_ce;
      o_spi_mosi <= i_spi_mosi;

      -- in any state: if ce goes high we return to idle
      if i_spi_ce = '1' then
        r_state <= s_Idle;
      end if;
      
      case r_state is
        when s_Idle =>
          -- reset everything
          o_dev_select <= (others => '0');
          r_dev <= (others => '0');
          r_count <= 0;
          -- wait for falling ce
          if r_ce_prev = '1' and i_spi_ce = '0' then
            r_state <= s_Addr;
          end if;
        when s_Addr =>
          -- look for rising spi clk
          if r_clk_prev = '0' and i_spi_clk = '1' then
            r_dev(g_DEV_SELECT_BITS - r_count - 1) <= i_spi_mosi;
            r_count <= (r_count + 1) mod g_DEV_SELECT_BITS;
            -- check for end condition
            if r_count = g_DEV_SELECT_BITS-1 then
              r_state <= s_Data;
            end if;
          end if;
        when s_Data =>
          o_dev_select <= r_dev;
          -- wait for end of transaction
          
        when s_Cleanup =>
          
      end case;
    end if; -- rising_edge(clk)
  end process;
  
end behave;
