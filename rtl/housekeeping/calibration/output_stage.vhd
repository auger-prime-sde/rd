library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_complex.all;
use ieee.math_real.all;

library work;
use work.icpx.all;

-- task:
-- wait for rising fft ready flag
-- unfudge the re/im
-- calculate power
-- add the current fft
-- keep track of fft count
-- (keep track of output size)

-- input flags take effect after fft summing round:
-- request clear
-- request break (suppress rearm)
-- 

-- we have to un-merge the fft result
-- see: http://www.robinscheibler.org/2013/02/13/real-fft.html
-- FFT_LEN = 1024 and LOG2_FFT_LEN = 10
-- these represent the parameters of the complex fft.
-- In fact we folded 2048 real samples by putting even and odd samles in the
-- real and complex parts of the input array. N = 2048
-- Now for the un-merging:
-- Let Z[k] be the complex fft bin for k = 0,1,...N/2-1
-- 

entity output_stage is
  generic (
    g_WIDTH : natural;
    g_SUM_WIDTH : natural := 18;
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
    o_busy : out std_logic;
    -- spi port
    i_hk_fast_clk : in std_logic;
    i_spi_clk : in std_logic;
    i_spi_ce  : in std_logic;
    o_spi_miso : out std_logic;
    i_max_ffts : in std_logic_vector(31 downto 0);
    o_num_ffts : out std_logic_vector(31 downto 0)
    );
end output_stage;

architecture behave of output_stage is
  constant FFT_LEN : natural := 2 ** LOG2_FFT_LEN;

  -- TODO: prevent overflow and set a warning
  type t_ram is array (FFT_LEN - 1 downto 0) of std_logic_vector(g_SUM_WIDTH - 1 downto 0);
  
  function zeros
    return t_ram is
    variable res : t_ram;
  begin
    for i in 0 to FFT_LEN - 1 loop
      res(i) := (others => '0');
    end loop;
    return res;
  end function zeros;

  signal power_ns, power_ew: t_ram := zeros;

  signal r_fft_count : natural := 0;-- range 0 to 2 ** 32 - 1 := 0;
  signal r_old_sum : unsigned(g_SUM_WIDTH-1 downto 0);

  type t_state is (s_Idle, s_Preload, s_Process, s_Readout, s_Clear);
  signal r_state : t_state := s_Idle;

  
  
  signal r_count : integer range 0 to FFT_LEN - 1 := 0;
  --signal sample_count : integer range 0 to LOG2_FFT_LEN-1 := 0;
  --signal bit_count    : integer range 0 to 31 := 0;

  signal r_preload, r_load, r_fudge_factor, r_Xk : compl;
  signal r_pow : unsigned(g_SUM_WIDTH-1 downto 0);
  signal r_fudge_factor_icpx : icpx_number;
  signal r_load_star, r_Xk_sum, r_Xk_diff, r_Xk_diff2 ,r_Xk_left, r_Xk_right : compl;
  signal r_fft_ready : std_logic := '1';

  
  type t_fudge is array (0 to FFT_LEN - 1) of std_logic_vector(2 * ICPX_WIDTH - 1 downto 0);
  
  function fudge_gen
    return t_fudge is
    variable c : complex;
    variable res : t_fudge;
  begin  -- function fudge_gen
    for i in 0 to FFT_LEN-1 loop
      c      := CMPLX(0.0, -1.0) * EXP(CMPLX(0.0, -2.0*MATH_PI*real(i)/real(2 * FFT_LEN)));
      res(i) := icpx2stlv(cplx2icpx(c));
    end loop;  -- i
    return res;
  end function fudge_gen;

  -- Fudge factor ROM memory
  signal fudge_factors : t_fudge := fudge_gen;
  
  attribute syn_ramstyle : string;
  attribute syn_romstyle : string;
  
  attribute syn_ramstyle of behave : architecture is "block_ram";
  attribute syn_ramstyle of fudge_factors : signal is "block_ram";
  attribute syn_romstyle of behave : architecture is "EBR";
  attribute syn_romstyle of fudge_factors : signal is "EBR";


  signal r_bitcount  : integer range 0 to g_SUM_WIDTH-1;
  signal r_spi_ce_prev, r_spi_clk_prev : std_logic := '0';

  signal r_power_read_addr : integer range 0 to FFT_LEN - 1;
  signal r_power_write_addr: integer range 0 to FFT_LEN - 1;
  signal r_power_ns_write_data, r_power_ns_read_data : std_logic_vector(g_SUM_WIDTH-1 downto 0);
  signal r_power_ew_write_data, r_power_ew_read_data : std_logic_vector(g_SUM_WIDTH-1 downto 0);
  signal r_power_write_enable_ns : std_logic := '0';
  signal r_power_write_enable_ew : std_logic := '0';

  signal r_fudge_load : std_logic_vector(2 * ICPX_WIDTH-1 downto 0);

  --signal test_power : integer range 0 to 2 ** (ICPX_WIDTH-1) - 1;
begin
  --test_power <= to_integer(r_pow.Re);
    
  o_busy <= '0' when r_state = s_Readout else '1';
    
  -- set output address to fft
  -- must be one step ahead of count always
  o_addr <= std_logic_vector(to_unsigned((FFT_LEN - r_count + 1) mod FFT_LEN, o_addr'length)) when r_state = s_Preload else
            std_logic_vector(to_unsigned(r_count, o_addr'length)) when r_State = s_Process else
            (others => '0');

  
  -- The whole calculation is done asynchonously in the same clk
  r_load <= (Re => signed(i_data_re), Im => signed(i_data_im), Ov => '0');

  
  -- complex conjugate for second part of data:
  r_load_star <= compl_conjugate(r_load);
  r_Xk_sum <= compl_add(r_load_star, r_preload);
  r_Xk_diff <= compl_sub(r_preload, r_load_star);
  r_Xk_left <= compl_div2 (r_Xk_sum);

  r_Xk_diff2 <= compl_div2(r_Xk_diff);
  r_Xk_right <= compl_mul(r_fudge_factor, r_Xk_diff2);
  r_Xk <= compl_add ( r_Xk_left, r_Xk_right );

  r_pow <= resize(compl_power(r_Xk), g_SUM_WIDTH);
  
  r_power_ns_read_data <= power_ns(r_power_read_addr);
  r_power_ew_read_data <= power_ew(r_power_read_addr);
  r_power_write_addr <= (r_count - 1) mod FFT_LEN;

  r_fudge_factor <= (
        Re => signed(r_fudge_load(2*ICPX_WIDTH-1 downto ICPX_WIDTH)),
        Im => signed(r_fudge_load(ICPX_WIDTH-1 downto 0)),
        Ov => '0' );

  
  r_power_write_enable_ns <= '1' when (r_state = s_Process and i_channel = '0') or r_state = s_Clear else '0';
  r_power_write_enable_ew <= '1' when (r_state = s_Process and i_channel = '1') or r_state = s_Clear else '0';

  
  r_old_sum <= unsigned(r_power_ns_read_data) when i_channel = '0' else unsigned(r_power_ew_read_data);

--  if i_channel = '0' then
    r_power_ns_write_data <= (others => '0') when r_state = s_Clear else std_logic_vector(resize(r_pow + r_old_sum, g_SUM_WIDTH));
--  else
    r_power_ew_write_data <= (others => '0') when r_state = s_Clear else std_logic_vector(resize(r_pow + r_old_sum, g_SUM_WIDTH));
--  end if;

          
  o_num_ffts <= std_logic_vector(to_unsigned(r_fft_count, 32));
  
  p_write : process(i_clk) is
  begin
    if rising_edge(i_clk) then
      
      r_fft_ready <= i_fft_ready;
      r_spi_clk_prev <= i_spi_clk;
      r_spi_ce_prev  <= i_spi_ce;
          
      
      
      if r_power_write_enable_ns = '1' then
        power_ns(r_power_write_addr) <= r_power_ns_write_data;
      end if;
      if r_power_write_enable_ew = '1' then
        power_ew(r_power_write_addr) <= r_power_ew_write_data;
      end if;
      
      --r_fudge_factor_icpx <= stlv2icpx(fudge_factors((r_count-1)mod FFT_LEN));
      
      --r_fudge_factor <= (Re => fudge_factors((FFT_LEN+r_count-1) mod FFT_LEN).Re, Im => fudge_factors((FFT_LEN+r_count-1) mod FFT_LEN).Im, Ov => '0');
      
      r_fudge_load <= fudge_factors((r_count-1)mod FFT_LEN);

      -- capture Z[k] 
      r_preload <= (Re => signed(i_data_re), Im => signed(i_data_im), Ov => '0');
          
      
      case r_state is

        
        when s_Idle =>
          
          -- end rearm pulse
          o_rearm <= '0';

          -- check for break requests
          if i_req_break = '1' then
            r_state <= s_Readout;
            r_count <= 1;
          end if;
          
          -- check if we should start an fft
          if i_fft_ready = '1' and r_fft_ready = '0' then
            r_state <= s_Preload;
            r_count <= 1;
            r_power_read_addr <= 0;
          end if;

          
        when s_Preload =>
          -- capture Z[k] 
          r_preload <= (Re => signed(i_data_re), Im => signed(i_data_im), Ov => '0');
          
          -- also remember the old sum
          
          r_state <= s_Process;
        when s_Process =>
          r_power_read_addr <= r_count;
          -- store the new sum
          -- TODO: I think this can be simplified by having a single write data:
                    
          -- use Z*[N/2-k] and fudge factor to compute Xk and consequently r_pow

          -- advance count
          r_count <= (r_count + 1) mod FFT_LEN;
          
          -- test if we are done
          -- depending on the requests we can go to several next states:
          if r_count = 0 then -- 1 being the last to process

            -- increment counter, it never overflows because the range of
            -- r_fft_count is unclusive of the upper limit
            r_fft_count <= r_fft_count + 1;
            
            -- handle break request, also break when max fft's have been averaged
            if r_fft_count = to_integer(unsigned(i_max_ffts)) - 1 or i_req_break = '1' then
              r_state <= s_Readout;
              r_count <= 1; -- should be surperfluous

            -- continue with the next fft
            else 
              r_state <= s_Idle;
              o_rearm <= '1';
            end if;

          else
            -- if not done, continue preloading the next bin
            r_state <= s_Preload;
          end if;

          -- In readout we pause the fft's and enable reading via spi
          -- TODO: After readout an extra rearm pulse occurs, that makes the
          -- input stage flip channel select
        when s_Readout =>
          -- on falling CE rewind
          if i_spi_ce = '0' and r_spi_ce_prev = '1' then
            r_power_read_addr <= 0;
            r_bitcount <= 0;
          end if;

          -- write a bit on the falling spi clock edge
          if i_spi_clk = '0' and r_spi_clk_prev = '1' then
            -- output bit
            if i_buffer_select = '0' then
              o_spi_miso <= r_power_ns_read_data(g_SUM_WIDTH-1-r_bitcount);
            else
              o_spi_miso <= r_power_ew_read_data(g_SUM_WIDTH-1-r_bitcount);
            end if;
            
            
            -- advance the counters
            if r_bitcount = g_SUM_WIDTH - 1 then
              r_bitcount <= 0;
              r_power_read_addr <= (r_power_read_addr + 1) mod FFT_LEN;
            else
              r_bitcount <= r_bitcount + 1 mod g_SUM_WIDTH;
            end if;
            
          end if;
          
          

          -- handle requests to clear
          if i_req_clear = '1' then
            r_state <= s_Clear;
            r_count <= 0;
            
          -- if there is room, continue when not on break  
          elsif i_req_break = '0' and r_fft_count < to_integer(unsigned(i_max_ffts)) then
            o_rearm <= '1';
            r_state <= s_Idle;
          end if;

        -- TODO: I believe shifting the meaning of r_count by +1 would
        -- simplify things a lot.
        when s_Clear =>
          r_fft_count <= 0;
          --power_ns((r_count - 1) mod FFT_LEN) <= (others => '0');
          --r_power_ns_write_data <= (others => '0');
          --r_power_ew_write_data <= (others => '0');
          --power_ew((r_count - 1) mod FFT_LEN) <= (others => '0');
          if r_count = FFT_LEN - 1 then
            -- rewind counter and go to readout for good measure (in case req
            -- break was also set)
            r_count <= 1; -- that's what the value normally is during idle
            r_state <= s_readout;
          else
            r_count <= r_count + 1;
            r_state <= s_Clear;
          end if;
      end case;
    end if;
  end process;
  
  
   
  
end behave;


