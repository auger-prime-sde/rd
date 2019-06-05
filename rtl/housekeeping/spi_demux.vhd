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
    i_spi_clk  : in  std_logic;
    i_hk_fast_clk: in std_logic;
    i_spi_mosi : in  std_logic;
    --o_spi_miso : out std_logic;
    i_spi_ce   : in  std_logic;
    -- muxer target output:
    o_dev_select   : inout std_logic_vector(g_DEV_SELECT_BITS-1 downto 0) := (others => '0')
    );
end spi_demux;

architecture behave of spi_demux is

  signal r_count   : natural range 0 to g_DEV_SELECT_BITS-1 := 0;
  signal r_device  : std_logic_vector(g_DEV_SELECT_BITS-1 downto 0);
  signal r_count_test : std_logic_vector(g_DEV_SELECT_BITS-1 downto 0);
  signal r_dev_out : std_logic_vector(g_DEV_SELECT_BITS-1 downto 0) := (others => '0');

  -- the following flag toggles between transactions (we could not use
  -- a boolean because we'de have no way to clear it from the main
  -- process) by remembering the ce line.
  signal r_reset_flag : std_logic := '1';
  signal r_prev_ce_0 : std_logic := '1';
  signal r_prev_ce_1 : std_logic := '1';
  -- and the main process remembers the flag state to detect toggles
  signal r_flag_state : std_logic := '0';


  -- only for debugging:
  signal r_count_t : std_logic_vector(3 downto 0);
  
begin
  o_dev_select <= (others => '0') when r_flag_state /= r_reset_flag else r_dev_out;
  r_count_t <= std_logic_vector(to_unsigned(r_count, 4));

  p_reset : process(i_hk_fast_clk) is
  begin
    if rising_edge(i_hk_fast_clk) then
      if r_prev_ce_0='1' and r_prev_ce_1='0' then -- i.e. rising edge
        r_reset_flag <= not r_reset_flag;
      end if;
      r_prev_ce_1 <= r_prev_ce_0;
      r_prev_ce_0 <= i_spi_ce;
    end if;
  end process;

  p_main : process(i_spi_clk) is
  begin
    if falling_edge(i_spi_clk) then
      if r_count = g_DEV_SELECT_BITS-1 then
        r_dev_out <= r_device;
        r_dev_out(g_DEV_SELECT_BITS-1) <= i_spi_mosi;
      end if;
    end if;
    
    if rising_edge(i_spi_clk) then
      if i_spi_ce = '0' then
        if r_flag_state /= r_reset_flag then
          -- latch first bit:
          r_device(g_DEV_SELECT_BITS-1) <= i_spi_mosi;
          r_dev_out <= (others => '0');
          r_count <= 0;
        else
          if r_count < g_DEV_SELECT_BITS - 1  then
            -- latch further dev bits:
            r_device(g_DEV_SELECT_BITS-r_count-2) <= i_spi_mosi;
            r_count <= r_count + 1;
            if r_count = g_DEV_SELECT_BITS - 2 then
              --r_dev_out <= r_device;
              --r_dev_out(g_DEV_SELECT_BITS-r_count-2) <= i_spi_mosi;
            end if;
          end if;
        end if; -- r_flag_state /= r_reset_flag
        --there is a bug in the lattice synthesizer that causes this
        -- code to make r_flag_state low on boot. The reason for this
        -- remains unknown but the code is written such that it does
        -- not matter. r_flag_state was low from the start anyway.
        r_flag_state <= r_reset_flag;
      end if; -- i_spi_ce = '0'
    end if; -- rising_edge(i_spi_clk)
  end process;
  
end behave;
