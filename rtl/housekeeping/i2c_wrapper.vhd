library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity i2c_wrapper is
  generic (
    g_SUBSYSTEM_ADDR : std_logic_vector;
    g_I2C_ADDR : std_logic_vector(6 downto 0);
    g_CLK_DIV : natural := 125; -- I.e. 100MHz/400khz/2
    -- divided by 2 because the i2c clock is half as fast as the internal clock
    -- used to produce it.
    g_SEQ_DATA : t_i2c_data
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
    io_hk_scl     : inout std_logic
    );
end i2c_wrapper;


architecture behaviour of i2c_wrapper is
  signal r_read_data    : std_logic_vector(7 downto 0);
  signal r_write_data   : std_logic_vector(7 downto 0);
  signal r_seq_data     : std_logic_vector(7 downto 0);
  signal r_spi_data     : std_logic_vector(7 downto 0);
  
  signal r_seq_datavalid: std_logic;
  signal r_write_enable : std_logic;
  signal r_read_enable  : std_logic;
  signal r_rw           : std_logic;
  signal r_restart      : std_logic;
  
  signal r_read_addr    : std_logic_vector(2 downto 0);
  signal r_write_addr   : std_logic_vector(2 downto 0);
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
      o_rw       : out std_logic;
      o_restart  : out std_logic;
      o_valid    : out std_logic;
      o_addr     : out std_logic_vector(2 downto 0)
      );
  end component;

  component i2c2 is
    generic (
      g_ADDR          : std_logic_vector(6 downto 0)
      );
    port(	--inputs
      i_clk      : in std_logic;
      i_data     : in std_logic_vector(7 downto 0);
      i_rw       : in std_logic;
      i_restart  : in std_logic;
      i_valid    : in std_logic;
      --outputs
      o_data     : out std_logic_vector (7 downto 0);
      o_datavalid: out std_logic;
      o_next     : out std_logic;
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
      i_read_clk    : in  std_logic;
      i_read_enable : in  std_logic;
      i_read_addr   : in  std_logic_vector(g_ADDRESS_WIDTH-1 downto 0);
      o_read_data   : out std_logic_vector(g_DATA_WIDTH-1 downto 0)
    );
  end component;


begin
  r_spi_ce <= '0' when i_dev_select = g_SUBSYSTEM_ADDR else '1';
  o_spi_miso <= not r_spi_ce and r_spi_miso;
  r_read_addr <= r_spi_data(2 downto 0);
  --r_read_enable <= '1' when r_recv_count = std_logic_vector(to_unsigned(0, r_recv_count'length)) else '0';
  r_read_enable <= '1' when r_recv_count = "00000000" else '0';
  
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
      o_data       => r_spi_data,
      i_data       => r_read_data,
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
      o_rw       => r_rw,
      o_restart  => r_restart,
      o_valid    => r_seq_datavalid,
      o_addr     => r_write_addr
      );
  
  i2c2_1 : i2c2
    generic map (
      g_ADDR     => g_I2C_ADDR
      )
    port map (
      i_clk       => r_i2c_clk,
      i_data      => r_seq_data,
      i_rw        => r_rw,
      i_restart   => r_restart,
      i_valid     => r_seq_datavalid,
      o_data      => r_write_data,
      o_datavalid => r_write_enable,
      o_next      => r_next,
      sda	      => io_hk_sda,
      scl	      => io_hk_scl
      );

  data_buffer_1 : housekeeping_buffer
    generic map (g_DATA_WIDTH => 8, g_ADDRESS_WIDTH => 3)
    port map (
      i_write_clk    => r_i2c_clk,
      i_write_enable => r_write_enable,
      i_write_addr   => r_write_addr,
      i_write_data   => r_write_data,
      i_read_clk     => i_hk_fast_clk,
      i_read_enable  => r_read_enable,
      i_read_addr    => r_read_addr,
      o_read_data    => r_read_data
      );
  
  
end architecture behaviour;

