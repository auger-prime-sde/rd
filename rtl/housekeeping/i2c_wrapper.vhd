library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity i2c_wrapper is
  generic (
    g_SUBSYSTEM_ADDR : std_logic_vector;
    g_CLK_DIV : natural := 125; -- I.e. 100MHz/400khz/2
    -- divided by 2 because the i2c clock is half as fast as the internal clock
    -- used to produce it.
    g_SEQ_DATA : t_i2c_data;
    g_OUTPUT_WIDTH : natural;
    g_ACK : std_logic := '0'
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
    io_hk_scl     : inout std_logic;

    -- parallel output of all bytes
    o_latched     : out std_logic_vector(2 ** g_OUTPUT_WIDTH * 8 - 1 downto 0)
    );
end i2c_wrapper;


architecture behaviour of i2c_wrapper is
  signal r_write_data   : std_logic_vector(7 downto 0);
  signal r_seq_data     : std_logic_vector(7 downto 0);
  signal r_spi_data     : std_logic_vector(7 downto 0);
  
  signal r_seq_datavalid: std_logic;
  signal r_write_enable : std_logic;
  signal r_read_enable  : std_logic;
  signal r_dir          : std_logic;
  signal r_restart      : std_logic;
  
  signal r_write_latch  : std_logic;
  signal r_read_latch   : std_logic;
  signal r_latch_buffer : std_logic := '0';
  signal r_read_done    : std_logic;
  signal r_full_data         :  std_logic_vector(2**g_OUTPUT_WIDTH*8-1 downto 0);
  signal r_byte_data    : std_logic_vector(7 downto 0);
  
  signal r_read_addr    : std_logic_vector(7 downto 0);
  signal r_write_addr   : std_logic_vector(7 downto 0);
  signal r_next         : std_logic;

  signal r_i2c_clk  : std_logic;
  
  signal r_spi_ce   : std_logic;
  signal r_spi_miso : std_logic;
  signal r_recv_count : std_logic_vector(7 downto 0);

  component clock_divider is
    generic (
      g_MAX_COUNT : natural);
    port (
      i_clk: in std_logic;
      o_clk: out std_logic);
  end component;
  
  component spi_decoder is
    generic (
      g_INPUT_BITS  : natural := 32;
      g_OUTPUT_BITS : natural := 32 );
    port (
      i_spi_clk    : in  std_logic;
      i_spi_mosi   : in  std_logic;
      o_spi_miso   : out std_logic;
      i_spi_ce     : in  std_logic;
      i_clk        : in  std_logic;
      o_data       : out std_logic_vector(g_INPUT_BITS-1 downto 0) := (others => '0');
      i_data       : in  std_logic_vector(g_OUTPUT_BITS-1 downto 0);
      o_recv_count : out std_logic_vector(g_INPUT_BITS-1 downto 0) );
  end component;

  component read_sequence is
    generic (
      g_SEQ_DATA : t_i2c_data
      );
    port (
      i_clk      : in std_logic;
      i_trig     : in std_logic;
      i_next     : in std_logic;
      o_data     : out std_logic_vector(7 downto 0);
      o_dir      : out std_logic;
      o_restart  : out std_logic;
      o_valid    : out std_logic;
      o_addr     : out std_logic_vector(7 downto 0);
      o_done     : out std_logic
      );
  end component;

  component i2c is
    generic (
      g_ACK : std_logic := '0'
      );
    port(	--inputs
      i_clk      : in std_logic;
      i_data     : in std_logic_vector(7 downto 0);
      i_dir      : in std_logic;
      i_restart  : in std_logic;
      i_valid    : in std_logic;
      --outputs
      o_data     : out std_logic_vector (7 downto 0);
      o_datavalid: out std_logic;
      o_next     : out std_logic;
      o_error    : out std_logic;
      -- i2c interface
      sda	     : inout std_logic := 'Z';
      scl	     : inout std_logic := 'Z'
      );
  end component;

  component housekeeping_buffer is
    generic (g_DATA_WIDTH: natural; g_ADDRESS_WIDTH : natural);
    port (
      i_write_clk   : in  std_logic;
      i_write_enable: in  std_logic;
      i_write_addr  : in  std_logic_vector(g_ADDRESS_WIDTH-1 downto 0);
      i_write_data  : in  std_logic_vector(g_DATA_WIDTH-1 downto 0);
      i_read_addr   : in  std_logic_vector(g_ADDRESS_WIDTH-1 downto 0);
      o_byte_data   : out std_logic_vector(7 downto 0);
      o_full_data   : out std_logic_vector(2**g_ADDRESS_WIDTH*g_DATA_WIDTH-1 downto 0);
      i_latch       : in std_logic
    );
  end component;


begin
  r_spi_ce <= '0' when i_dev_select = g_SUBSYSTEM_ADDR else '1';
  o_spi_miso <= not r_spi_ce and r_spi_miso;

  r_read_latch <= not r_spi_ce; -- latch for read when ce low
  r_write_latch <= not r_read_done; -- latch for write during write
  -- old data is latched as long as either read or write is in progress.
  --r_latch_buffer <= '1' when r_read_latch = '1' or r_write_latch = '1' else '0';

  p_latch : process(r_i2c_clk) is
  begin
    if rising_edge(r_i2c_clk) then
      if r_latch_buffer = '0' then
        -- start latching when write is first enabled
        if r_write_enable = '1' then
          r_latch_buffer <= '1';
        end if;
      else
        -- stop latching when read_done is received
        if r_read_done = '1' then
          r_latch_buffer <= '0';
        end if;
      end if;
    end if;
  end process;

  o_latched <= r_full_data;
  
  spi_decoder_1 : spi_decoder
    generic map (
      g_INPUT_BITS  => 8,
      g_OUTPUT_BITS => 8
      )
    port map (
      i_spi_clk    => i_spi_clk,
      i_spi_mosi   => i_spi_mosi,
      o_spi_miso   => r_spi_miso,
      i_spi_ce     => r_spi_ce,
      i_clk        => i_hk_fast_clk,
      o_data       => r_read_addr,
      i_data       => r_byte_data,
      o_recv_count => r_recv_count
      );

  clock_divider_i2c : clock_divider
    generic map (
      g_MAX_COUNT => g_CLK_DIV -- from 100 MHz to 312.5 kHz (i2c clock is half as
                         -- fast as input clk)
      )
    port map (
      i_clk => i_hk_fast_clk,
      o_clk => r_i2c_clk
      );

  read_sequence_1 : read_sequence
    generic map (
      g_SEQ_DATA => g_SEQ_DATA
      )
    port map (
      i_clk      => r_i2c_clk,
      i_trig     => i_trigger,
      i_next     => r_next,
      o_data     => r_seq_data,
      o_dir      => r_dir,
      o_restart  => r_restart,
      o_valid    => r_seq_datavalid,
      o_addr     => r_write_addr,
      o_done     => r_read_done
      );
  
  i2c_1 : i2c
    generic map (
      g_ACK => g_ACK
      )
    port map (
      i_clk       => r_i2c_clk,
      i_data      => r_seq_data,
      i_dir       => r_dir,
      i_restart   => r_restart,
      i_valid     => r_seq_datavalid,
      o_data      => r_write_data,
      o_datavalid => r_write_enable,
      o_next      => r_next,
      o_error     => open,
      sda	      => io_hk_sda,
      scl	      => io_hk_scl
      );

  data_buffer_1 : housekeeping_buffer
    generic map (g_DATA_WIDTH => 8, g_ADDRESS_WIDTH => g_OUTPUT_WIDTH)
    port map (
      i_write_clk    => r_i2c_clk,
      i_write_enable => r_write_enable,
      i_write_addr   => r_write_addr(g_OUTPUT_WIDTH-1 downto 0),
      i_write_data   => r_write_data,
      i_read_addr    => r_read_addr(g_OUTPUT_WIDTH-1 downto 0),
      o_byte_data    => r_byte_data,
      o_full_data    => r_full_data,
      i_latch        => r_latch_buffer
      );
  
  
end architecture behaviour;

