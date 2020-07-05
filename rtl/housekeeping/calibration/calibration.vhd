library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_complex.all;

library work;
use work.fft_len.all;
use work.icpx.all;

entity calibration is
  generic (
    g_CONTROL_SUBSYSTEM_ADDR : std_logic_vector;
    g_READOUT_SUBSYSTEM_ADDR : std_logic_vector;
    g_ADC_BITS : natural := 12;
    LOG2_FFT_LEN : integer := 11;
    QUIET_THRESHOLD : integer := 50
    );
  port (
    -- clk
    i_data_clk    : in std_logic;
    i_fft_clk     : in std_logic;
    i_hk_fast_clk : in std_logic;
    -- data input:
    i_data_ns_even : in std_logic_vector(g_ADC_BITS-1 downto 0);
    i_data_ns_odd  : in std_logic_vector(g_ADC_BITS-1 downto 0);
    i_data_ew_even : in std_logic_vector(g_ADC_BITS-1 downto 0);
    i_data_ew_odd  : in std_logic_vector(g_ADC_BITS-1 downto 0);
    -- spi interface for readout:
    i_spi_clk     : in std_logic;
    i_dev_select  : in std_logic_vector(g_CONTROL_SUBSYSTEM_ADDR'length-1 downto 0);
    i_spi_mosi    : in std_logic;
    o_spi_miso    : out std_logic
    );
end calibration;

-- idea:
-- input_stage stores N samples at high speed and monitors for thresholds. When
-- the threshold is exceeded, it rewinds and start over. When all samples are
-- received (buffer is full) it triggers the next stage.
-- the input stage streams the data into the fft engine which then streams it
-- into the output stage which stores and accumulates it until readout.
--


architecture behave of calibration is

  --signal r_fft_in, r_fft_out : icpx_number;
  component simple_counter is
    generic (g_SIZE : natural := 11);
    port (
      i_clk: in  std_logic;
      o_count: out  std_logic_vector(g_SIZE-1 downto 0));
  end component;
  
  
  component input_stage is
    generic (
      g_ADC_BITS : natural := 12;
      LOG2_FFT_LEN : integer := 11;
      QUIET_THRESHOLD : integer := 50
      );
    port (
      i_data_clk : in std_logic;
      i_fft_clk   : in std_logic;
      i_data_ns_even : in std_logic_vector(g_ADC_BITS-1 downto 0);
      i_data_ns_odd  : in std_logic_vector(g_ADC_BITS-1 downto 0);
      i_data_ew_even : in std_logic_vector(g_ADC_BITS-1 downto 0);
      i_data_ew_odd  : in std_logic_vector(g_ADC_BITS-1 downto 0);
      o_valid   : out std_logic;
      o_addr    : out std_logic_vector(LOG2_FFT_LEN-1 downto 0);
      o_start   : out std_logic;
      o_data_even : out std_logic_vector(ICPX_WIDTH-1 downto 0);
      o_data_odd  : out std_logic_vector(ICPX_WIDTH-1 downto 0);
      i_rearm   : in std_logic;
      o_channel : out std_logic
      );
  end component;

   
  
--component fft_engine 
--  generic (
--    LOG2_FFT_LEN : integer := 4
--    );
--  port (
--    -- System interface
--    rst_n     : in  std_logic;
--    clk       : in  std_logic;
--    -- Input memory interface
--    din       : in  icpx_number;        -- data input
--    valid     : out std_logic;
--    saddr     : out unsigned(LOG2_FFT_LEN-2 downto 0);
--    saddr_rev : out unsigned(LOG2_FFT_LEN-2 downto 0);
--    sout0     : out icpx_number;        -- spectrum output
--    sout1     : out icpx_number         -- spectrum output
--    );
--end component;
--
  component fft_engine is
    generic (
      LOG2_FFT_LEN : integer := 8 );
    port (
      din       : in  icpx_number;
      addr_in   : in  integer;
      wr_in     : in  std_logic;
      dout      : out icpx_number;
      addr_out  : in  integer;
      ready     : out std_logic;
      busy      : out std_logic;
      start     : in  std_logic;
      rst_n     : in  std_logic;
      syn_rst_n : in  std_logic;
      clk       : in  std_logic);
  end component;
  
  component output_stage is
    generic (
      g_WIDTH : natural;
      LOG2_FFT_LEN : integer := 11
      );
    port (
      i_clk : in std_logic;
      i_fft_ready : in std_logic;
      i_channel : in std_logic;
      i_data_re : in std_logic_vector(g_WIDTH-1 downto 0);
      i_data_im : in std_logic_vector(g_WIDTH-1 downto 0);
      o_addr : out std_logic_vector(LOG2_FFT_LEN-1 downto 0);
      o_rearm : out std_logic;
      i_req_break : in std_logic;
      i_req_clear : in std_logic;
      i_buffer_select : in std_logic;
      o_busy  : out std_logic;
      -- spi port
      i_hk_fast_clk : in std_logic;
      i_spi_clk : in std_logic;
      i_spi_ce  : in std_logic;
      o_spi_mosi : out std_logic
      );
  end component;

  component spi_register is
    generic (
      g_SUBSYSTEM_ADDR : std_logic_vector;
      g_REGISTER_WIDTH : natural := 8;
      g_DEFAULT : std_logic_vector(g_REGISTER_WIDTH-1 downto 0)
      );
    port (
      i_hk_fast_clk : in std_logic;
      i_spi_clk : in std_logic;
      i_spi_mosi : in std_logic;
      o_spi_miso : out std_logic;
      i_dev_select : in std_logic_vector(g_SUBSYSTEM_ADDR'length-1 downto 0);
      i_set : in std_logic_vector(g_REGISTER_WIDTH-1 downto 0);
      i_clr : in std_logic_vector(g_REGISTER_WIDTH-1 downto 0);
      o_data: out std_logic_vector(g_REGISTER_WIDTH-1 downto 0)
      );
  end component;

  signal r_channel : std_logic;
  
  signal fft_in, fft_out : icpx_number;
  signal fft_in_re, fft_in_im : std_logic_vector(ICPX_WIDTH-1 downto 0);
  signal fft_out_re, fft_out_im : std_logic_vector(ICPX_WIDTH-1 downto 0);
  --signal fft_out_re, fft_out_im : std_logic_vector(15 downto 0);

  signal input_valid, enable_not : std_logic;
  signal fft_start : std_logic;
  --signal fft_out_valid : std_logic;
  --signal fft_out_addr, fft_out_rev_addr : unsigned(LOG2_FFT_LEN-2 downto 0);

  -- temporary vector to prevent a bit-reversal error in LSE
  signal tmp : std_logic_vector(2 * ICPX_WIDTH - 1 downto 0);
  signal fft_busy, fft_ready : std_logic;

  signal r_addr, r_addr_rev, r_addr_out, r_addr_out_rev : std_logic_vector(LOG2_FFT_LEN-1 downto 0);
  signal addr, addr_out : integer;
  signal r_rearm : std_logic;
  signal r_control_miso, r_readout_miso : std_logic;
  signal r_control_reg : std_logic_vector(7 downto 0);
  signal r_output_stage_busy : std_logic;
  signal r_readout_ce : std_logic;
begin

--  addr_counter : simple_counter
--    generic map (
--      g_SIZE => LOG2_FFT_LEN
--      )
--    port map (
--      i_clk => i_hk_clk,
--      o_count => r_addr
--      );
--      

  
  inp : input_stage
    generic map (
      g_ADC_BITS => g_ADC_BITS,
      LOG2_FFT_LEN => LOG2_FFT_LEN,
      QUIET_THRESHOLD => 500
      )
    port map (
      i_data_clk => i_data_clk,
      i_fft_clk  => i_fft_clk,
      i_data_ns_even => i_data_ns_even,
      i_data_ns_odd => i_data_ns_odd,
      i_data_ew_even => i_data_ew_even,
      i_data_ew_odd => i_data_ew_odd,
      o_valid => input_valid,
      o_addr => r_addr,
      o_start => fft_start,
      o_data_even => fft_in_re,
      o_data_odd => fft_in_im,
      i_rearm => r_rearm,
      o_channel => r_channel
      );

  outp : output_stage
    generic map (
      g_WIDTH => ICPX_WIDTH,
      LOG2_FFT_LEN => LOG2_FFT_LEN
      )
    port map (
      i_clk => i_fft_clk,
      i_fft_ready => fft_ready,
      i_channel => r_channel,
      i_data_re => fft_out_re,
      i_data_im => fft_out_im,
      o_addr => r_addr_out,
      o_rearm => r_rearm,
      i_req_break => r_control_reg(0),
      i_req_clear => r_control_reg(1),
      i_buffer_select => r_control_reg(2),
      o_busy => r_output_stage_busy,
      i_hk_fast_clk => i_hk_fast_clk,
      i_spi_clk => i_spi_clk,
      i_spi_ce => r_readout_ce,
      o_spi_mosi => r_readout_miso
      );
--
  enable_not <= not input_valid;
  fft_out_re <= std_logic_vector(fft_out.Re);
  fft_out_im <= std_logic_vector(fft_out.Im);

  -- tmp pads the numbers with either 0's or 1's depending on the sign
  tmp <= std_logic_vector(to_signed(to_integer(signed(fft_in_re)), ICPX_WIDTH))  & std_logic_vector(to_signed(to_integer(signed(fft_in_im)), ICPX_WIDTH));
  fft_in <= stlv2icpx(tmp);
  addr <= to_integer(unsigned(r_addr));
  addr_out <= to_integer(unsigned(r_addr_out_rev));
  gen: for i in 0 to LOG2_FFT_LEN-1 generate
    r_addr_out_rev(i) <=  r_addr_out(LOG2_FFT_LEN-i-1);
    r_addr_rev(i)     <=  r_addr(LOG2_FFT_LEN-i-1);
  end generate;


  control_reg : spi_register
    generic map (
      g_SUBSYSTEM_ADDR => g_CONTROL_SUBSYSTEM_ADDR,
      g_REGISTER_WIDTH => 8,
      g_DEFAULT => (others => '0')
      )
    port map (
      i_hk_fast_clk => i_hk_fast_clk,
      i_spi_clk => i_spi_clk,
      i_spi_mosi => i_spi_mosi,
      o_spi_miso => r_control_miso,
      i_dev_select => i_dev_select,
      i_set(7)  => r_output_stage_busy,
      i_set(6 downto 0) => (others => '0'),
      i_clr(7)  => not r_output_stage_busy,
      i_clr(6 downto 0) => (others => '0'),
      o_data => r_control_reg
      );
        
  
--multi_unit_fft : fft_engine
--  generic map (
--    LOG2_FFT_LEN => LOG2_FFT_LEN
--    )
--  port map (
--    rst_n => enable_not,
--    clk   => i_hk_clk,
--    din   => fft_in,
--    valid => fft_out_valid,
--    saddr => fft_out_addr,
--    saddr_rev => fft_out_rev_addr,
--    sout0 => fft_out,
--    sout1 => stub
--    );

  single_unit_fft : fft_engine
    generic map (
      LOG2_FFT_LEN => LOG2_FFT_LEN
      )
    port map (
      din       => fft_in,
      addr_in   => addr,
      wr_in     => input_valid,
      dout      => fft_out,
      addr_out  => addr_out, --  : in  integer;
      ready     => fft_ready, --     : out std_logic;
      busy      => fft_busy, --     : out std_logic;
      start     => fft_start,--    : in  std_logic;
      rst_n     => '1',
      syn_rst_n => '1',
      clk       => i_fft_clk
      );

--  r_miso <= fft_out_re(0) xor
--            fft_out_re(1) xor
--            fft_out_re(2) xor
--            fft_out_re(3) xor
--            fft_out_re(4) xor
--            fft_out_re(5) xor
--            fft_out_re(6) xor
--            fft_out_re(7) xor
--            fft_out_re(8) xor
--            fft_out_re(9) xor
--            fft_out_re(10) xor
--            fft_out_re(11) xor
--            fft_out_im(0) xor
--            fft_out_im(1) xor
--            fft_out_im(2) xor
--            fft_out_im(3) xor
--            fft_out_im(4) xor
--            fft_out_im(5) xor
--            fft_out_im(6) xor
--            fft_out_im(7) xor
--            fft_out_im(8) xor
--            fft_out_im(9) xor
--            fft_out_im(10) xor
--            fft_out_im(11);
--            

  r_readout_ce <= '0' when i_dev_select = g_READOUT_SUBSYSTEM_ADDR else '1';
  o_spi_miso <= r_control_miso when i_dev_select = g_CONTROL_SUBSYSTEM_ADDR else
                r_readout_miso when i_dev_select = g_READOUT_SUBSYSTEM_ADDR else '0';
  

-- 32 EBR blocks available in ECP5
-- 11 in use by other systems, 21 free to use for calibration
-- both streaming and block fft require pre-buffering because 250MHz is too fast
-- both streaming and block fft require post-buffer for summing
-- FFT size | prebuf | postbuf | streaming fft | block fft
-- 2048     |      6 |       6 | 7 + 24 = 31   | 8
-- 1024     |      3 |       3 | 7 + 22 = 29   | 
--  512     |      2 |       2 | 7 + 20 = 27   | 
--  256     |      2 |       2 | 7 + 18 = 25   | 
-- Tomas: 1k FFT good enough, 512 is border line
  
end behave;      
    

