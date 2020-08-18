library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dac is
  generic (
    g_SUBSYSTEM_ADDR : std_logic_vector;
    g_CLK_DIV : natural := 125
    );
    port (
      i_hk_fast_clk : in std_logic;
      i_dev_select : in std_logic_vector(g_SUBSYSTEM_ADDR'length-1 downto 0);
      -- spi port
      i_spi_clk : in std_logic;
      i_spi_mosi : in std_logic;
      o_spi_miso: out std_logic;
      -- i2c port:
      sda : inout std_logic;
      scl : inout std_logic
      );
end dac;

architecture behave of dac is
  type t_state is (s_Idle, s_Busy);
  signal r_state : t_state := s_Idle;
  
  
  signal r_spi_ce,r_spi_miso : std_logic;
  signal r_i2c_clk : std_logic;
  signal r_i2c_next, r_i2c_next_prev, r_i2c_valid : std_logic;
  signal r_spi_recv_count : std_logic_vector(31 downto 0);
  signal r_i2c_dir, r_i2c_restart : std_logic;
  signal r_i2c_word_count : natural range 0 to 3 := 3;
  


  signal r_i2c_data : std_logic_vector(7 downto 0);
  signal r_spi_data : std_logic_vector(31 downto 0);

  --signal r_i2c_slave_addr : std_logic_vector(6 downto 0);
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

begin
  r_spi_ce <= '0' when i_dev_select = g_SUBSYSTEM_ADDR else '1';
  o_spi_miso <= not r_spi_ce and r_spi_miso;
  r_i2c_dir <= r_spi_data(24);

  
  clock_divider_i2c : clock_divider
    generic map (
      g_MAX_COUNT => g_CLK_DIV -- from 100 MHz to 312.5 kHz (i2c clock is half as
     -- fast as input clk)
      )
    port map (
      i_clk => i_hk_fast_clk,
      o_clk => r_i2c_clk
      );

  i2c_1 : i2c
    generic map (
      g_ACK => '0'
      )
    port map (
      i_clk       => r_i2c_clk,
      i_data      => r_i2c_data,
      i_dir       => r_i2c_dir,
      i_restart   => r_i2c_restart,
      i_valid     => r_i2c_valid,
      o_data      => open,
      o_datavalid => open,
      o_next      => r_i2c_next,
      o_error     => open,
      sda	      => sda,
      scl	      => scl
      );

  
  spi_decoder_1 : spi_decoder
    generic map (
      g_INPUT_BITS  => 32,
      g_OUTPUT_BITS => 32
      )
    port map (
      i_spi_clk    => i_spi_clk,
      i_spi_mosi   => i_spi_mosi,
      o_spi_miso   => r_spi_miso,
      i_spi_ce     => r_spi_ce,
      i_clk        => i_hk_fast_clk,
      o_data       => r_spi_data,
      i_data       => (others => '0'),
      o_recv_count => r_spi_recv_count
      );

  r_i2c_data <= r_spi_data(31 downto 24) when r_i2c_word_count = 0 else
                r_spi_data(23 downto 16) when r_i2c_word_count = 1 else
                r_spi_data(15 downto  8) when r_i2c_word_count = 2 else
                r_spi_data( 7 downto  0) when r_i2c_word_count = 3;
                
  
  p : process(i_hk_fast_clk) is
  begin
    if rising_edge(i_hk_fast_clk) then
      r_i2c_next_prev <= r_i2c_next;
      case r_state is
        when s_Idle =>
          if to_integer(unsigned(r_spi_recv_count)) = 31 then
            r_state <= s_Busy;
            r_i2c_word_count <= 0;
            r_i2c_valid <= '1';
            r_i2c_restart <= '1';
          end if;
        when s_Busy =>
          if r_i2c_next = '1' and r_i2c_next_prev = '0' then
            r_i2c_restart <= '0';
            if r_i2c_word_count = 3 then
              r_state <= s_Idle;
              r_i2c_valid <= '0';
            else
              r_i2c_word_count <= (r_i2c_word_count + 1) mod 4;
            end if;
          end if;
      end case;
    end if;
  end process;
     
  
end behave;

