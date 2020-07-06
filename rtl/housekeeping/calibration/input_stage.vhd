library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

-- The input stage is responsible for slicing quiet areas is the time domain,
-- for keeping track of rolling mean and rms, for buffering the input, and for
-- signalling the fft engine to start when the buffer is full.


library work;
use work.fft_len.all;
use work.icpx.all;


entity input_stage is
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
      o_valid     : out std_logic;
      o_addr      : out std_logic_vector(LOG2_FFT_LEN-1 downto 0);
      o_start     : out std_logic;
      o_data_even : out std_logic_vector(ICPX_WIDTH-1 downto 0);
      o_data_odd  : out std_logic_vector(ICPX_WIDTH-1 downto 0);
      i_rearm     : in std_logic;
      o_channel   : out std_logic
      );
end input_stage;


architecture behave of input_stage is

  attribute syn_ramstyle : string;
  attribute syn_ramstyle of behave : architecture is "block_ram";
  attribute syn_romstyle : string;
  attribute syn_romstyle of behave : architecture is "EBR";

  
  signal mean_ns, mean_ew : integer range -(2 ** (g_ADC_BITS - 1)) to 2 ** (g_ADC_BITS - 1) - 1;
  signal r_corrected_ns_even, r_corrected_ns_odd, r_corrected_ew_even, r_corrected_ew_odd : integer range -(2 ** (g_ADC_BITS - 1)) to 2 ** (g_ADC_BITS - 1) - 1;
  signal w_write_data : std_logic_vector(2 * g_ADC_BITS - 1 downto 0);
  
  --
  signal r_input_select : std_logic := '0';
  signal w_over_thres : std_logic := '1';
  signal w_over_thres_ns, w_over_thres_ew, w_over_thres_ns_stretch, w_over_thres_ew_stretch : std_logic;

  
  -- write controller
  -- The initial state is only needed for sim
  type t_write_state is (s_Write_initial, s_Write_Busy, s_Write_Idle);
  signal r_write_state : t_write_state := s_write_initial;
  --signal r_write_addr : std_logic_vector(LOG2_FFT_LEN - 1 downto 0) := (others => '0');
  signal r_write_addr : integer range 0 to 2 ** LOG2_FFT_LEN - 1 := 0;

  -- read controller
  type t_read_state is (s_Read_Idle, s_Read_Busy, s_Read_Delay);
  signal r_read_state : t_read_state := s_Read_Idle;
  signal r_read_data_even, r_read_data_odd : std_logic_vector(g_ADC_BITS-1 downto 0);
  signal r_read_addr : integer range 0 to 2 ** LOG2_FFT_LEN - 1 := 0;

  signal r_window : std_logic_vector(2 * ICPX_WIDTH - 1 downto 0);
  signal r_window_even, r_window_odd : signed(ICPX_WIDTH-1 downto 0);
  
  --signal r_rdaddress : std_logic_vector(10 downto 0);
  --signal r_wrAddress : std_logic_vector( 9 downto 0);
  -- signals between read and write clock:
  signal buffer_full : std_logic := '0';
  signal buffer_full_stretch : std_logic;
  signal buffer_full_sync : std_logic;
  --signal rearm : std_logic := '0';
  --signal rearm_sync : std_logic;
  --signal r_write_enable : std_logic;
  
  type t_ram is array (0 to 2 ** LOG2_FFT_LEN - 1) of std_logic_vector(2 * g_ADC_BITS-1 downto 0);
  signal ram : t_ram;

  signal r_valid : std_logic := '0';

  -- window function
  constant FFT_LEN : natural := 2 * 2 ** LOG2_FFT_LEN;
  -- twice because we abuse a 1024 bin complex FFT to compute a 2048 bin real fft.
  -- TODO: check that it's symmetrical and ditch half of this buffer

  
  type t_window is array (0 to FFT_LEN / 2 - 1) of std_logic_vector(2 * ICPX_WIDTH - 1 downto 0);
  function window_gen
    return t_window is
    variable x_even, x_odd : real;
    variable w_even, w_odd : real;
    variable v_even, v_odd : std_logic_vector(ICPX_WIDTH - 1 downto 0);
    variable res : t_window;
  begin  -- function window_gen
    for i in 0 to FFT_LEN / 2 - 1 loop
      x_even := real(2 * i    ) * 2.0 * MATH_PI / real(FFT_LEN - 1);
      x_odd  := real(2 * i + 1) * 2.0 * MATH_PI / real(FFT_LEN - 1);
      w_even := 0.27105140069342
              - 0.43329793923448 * cos(       x_even )
              + 0.21812299954311 * cos( 2.0 * x_even )
              - 0.06592544638803 * cos( 3.0 * x_even )
              + 0.01081174209837 * cos( 4.0 * x_even )
              - 0.00077658482522 * cos( 5.0 * x_even )
              + 0.00001388721735 * cos( 6.0 * x_even );
      w_odd  := 0.27105140069342
              - 0.43329793923448 * cos(       x_odd )
              + 0.21812299954311 * cos( 2.0 * x_odd )
              - 0.06592544638803 * cos( 3.0 * x_odd )
              + 0.01081174209837 * cos( 4.0 * x_odd )
              - 0.00077658482522 * cos( 5.0 * x_odd )
              + 0.00001388721735 * cos( 6.0 * x_odd );
      -- the window function is <1 everywhere so we use all bits except the
      -- sign bit for the factional part, hence ICPX_WIDTH - 1
      v_even := std_logic_vector(to_signed(integer(w_even * 2.0 ** (ICPX_WIDTH-1)), ICPX_WIDTH));
      v_odd  := std_logic_vector(to_signed(integer(w_odd  * 2.0 ** (ICPX_WIDTH-1)), ICPX_WIDTH));
      res(i) := v_even & v_odd;
    end loop;  -- i
    return res;
  end function window_gen;
  -- Window function ROM memory
  signal window_function : t_window := window_gen;


  
  component running_avg is
    generic (
      g_ADC_BITS : natural := 12;
      g_AVG_NUM_BITS : natural := 12 -- for 4096 sample averaged output 
      );
    port (
      i_clk : std_logic;
      i_data_even : in std_logic_vector(g_ADC_BITS-1 downto 0);
      i_data_odd  : in std_logic_vector(g_ADC_BITS-1 downto 0);
      --o_avg       : out std_logic_vector(g_ADC_BITS-1 downto 0)
      o_avg       : out integer range -(2 ** (g_ADC_BITS - 1)) to 2 ** (g_ADC_BITS - 1) - 1
      );
  end component;


  component sync_1bit is
    generic (
      g_NUM_STAGES : natural := 3
      );
    port (
      i_clk : in std_logic;
      i_data : in std_logic;
      o_data : out std_logic
      );
  end component;

  component  stretch is
    generic (
      g_LENGTH : natural := 3
      );
    port (
      i_clk  : in std_logic;
      i_data : in std_logic;
      o_data : out std_logic
      );
  end component;
  
begin
  

  running_avg_ns : running_avg
    generic map (
      g_ADC_BITS => g_ADC_BITS,
      g_AVG_NUM_BITS => 10
      )
    port map (
      i_clk       => i_data_clk,
      i_data_even => i_data_ns_even,
      i_data_odd  => i_data_ns_odd,
      o_avg       => mean_ns
      );

  running_avg_ew : running_avg
    generic map (
      g_ADC_BITS => g_ADC_BITS,
      g_AVG_NUM_BITS => 8
      )
    port map (
      i_clk       => i_data_clk,
      i_data_even => i_data_ew_even,
      i_data_odd  => i_data_ew_odd,
      o_avg       => mean_ew
      );


  stretch_buffer_full : stretch
    generic map (
      g_LENGTH => 50
      )
    port map (
      i_clk  => i_data_clk,
      i_data => buffer_full,
      o_data => buffer_full_stretch
      );
  
  sync_buffer_full : sync_1bit
    port map (
      i_clk  => i_fft_clk,
      i_data => buffer_full_stretch,
      o_data => buffer_full_sync
      );

  -- these stretch instances are not use for clock domain crossing but just to
  -- stretch the block-out window after a time-domain spike (broad spectrum noise)
  stretch_over_thres_ns : stretch
    generic map (
      g_LENGTH => 10 -- 10 clocks, 20 samples
      )
    port map (
      i_clk => i_data_clk,
      i_data => w_over_thres_ns,
      o_data => w_over_thres_ns_stretch
      );

  stretch_over_thres_ew : stretch
    generic map (
      g_LENGTH => 10 -- 10 clocks, 20 samples
      )
    port map (
      i_clk => i_data_clk,
      i_data => w_over_thres_ew,
      o_data => w_over_thres_ew_stretch
      );

  


  o_channel <= r_input_select;
  
  r_corrected_ns_even <= to_integer(signed(i_data_ns_even)) - mean_ns;
  r_corrected_ns_odd  <= to_integer(signed(i_data_ns_odd )) - mean_ns;
  r_corrected_ew_even <= to_integer(signed(i_data_ew_even)) - mean_ew;
  r_corrected_ew_odd  <= to_integer(signed(i_data_ew_odd )) - mean_ew;


  w_over_thres_ns <= '1' when (
    (
      r_corrected_ns_odd > QUIET_THRESHOLD or r_corrected_ns_odd < -QUIET_THRESHOLD
    ) or (
      r_corrected_ns_even > QUIET_THRESHOLD or r_corrected_ns_even < -QUIET_THRESHOLD
    )
  ) else '0';
  w_over_thres_ew <= '1' when (
    (
      r_corrected_ew_odd > QUIET_THRESHOLD or r_corrected_ew_odd < -QUIET_THRESHOLD
    ) or (
      r_corrected_ew_even > QUIET_THRESHOLD or r_corrected_ew_even < -QUIET_THRESHOLD
    )
    ) else '0';

  
  
  w_over_thres <= w_over_thres_ns_stretch when r_input_select = '0' else w_over_thres_ew_stretch;
  w_write_data <= i_data_ns_even & i_data_ns_odd when r_input_select = '0' else i_data_ew_even & i_data_ew_odd;

  
  -- input buffer stage. We use a linear buffer, whenever the input is outside
  -- the threshold area we reset the counter. when the counter hits the end of
  -- the buffer we trigger the output and restart.
  p_write : process(i_data_clk) is -- 125 MHz
  begin
    if rising_edge(i_data_clk) then
      case r_write_state is
        when s_write_initial =>
          r_write_state <= s_Write_Busy;
        when s_Write_Busy =>
          buffer_full <= '0';
          if w_over_thres = '1' then
            -- reset
            r_write_addr <= 0;
          else
            ram(r_write_addr) <= w_write_data;
            
            -- check if done, else increment
            if r_write_addr = 2 ** LOG2_FFT_LEN - 1 then
              r_write_addr <= 0;
              r_write_state <= s_Write_Idle;
              buffer_full <= '1';
            else
              r_write_addr <=  r_write_addr + 1;
            end if;
          end if;
        when s_Write_Idle =>
          buffer_full <= '0';
          if i_rearm = '1' then
            r_input_select <= not r_input_select;
            r_write_addr <= 0;
            r_write_state <= s_Write_Busy;
          end if;
      end case;
    end if;
  end process;
  
  -- TODO: the handshake between read and write needs to be fortified such that
  -- arm and buffer_full stay high until the other one acknowledges by going low.
  r_read_data_even <= ram(r_read_addr)(2*g_ADC_BITS-1 downto g_ADC_BITS);
  r_read_data_odd  <= ram(r_read_addr)(  g_ADC_BITS-1 downto          0);
  
  --r_window_even    <= signed(window_function(2*r_read_addr));
  --r_window_odd     <= signed(window_function(2*r_read_addr + 1));

  r_window <= window_function(r_read_addr);
  r_window_even    <= signed(r_window(2 * ICPX_WIDTH - 1 downto ICPX_WIDTH));
  r_window_odd     <= signed(r_window(     ICPX_WIDTH - 1 downto          0));


  
  p_read : process (i_fft_clk) is -- 100 MHz
  begin
    if rising_edge(i_fft_clk) then
      
      o_addr <= std_logic_vector(to_unsigned(r_read_addr, o_addr'length));
      o_data_even <= std_logic_vector(to_signed(to_integer(signed(r_read_data_even)) * to_integer(signed(r_window_even)), ICPX_WIDTH + g_ADC_BITS)(ICPX_WIDTH+g_ADC_BITS-1 downto g_ADC_BITS));
      o_data_odd  <= std_logic_vector(to_signed(to_integer(signed(r_read_data_odd )) * to_integer(signed(r_window_odd )), ICPX_WIDTH + g_ADC_BITS)(ICPX_WIDTH+g_ADC_BITS-1 downto g_ADC_BITS));
      
      case r_read_state is
        when s_Read_Idle =>
          o_valid <= '0';
          o_start <= '0';
          r_read_addr <= 0;
          if buffer_full_sync = '1' then
            r_read_state <= s_Read_Busy;
--            o_valid <= '1';
          end if;
        when s_Read_Busy =>
          o_valid <= '1';
          o_start <= '0';
                    
          if r_read_addr = 2 ** LOG2_FFT_LEN - 1 then
            r_read_state <= s_Read_Delay;
 --           o_valid <= '0';
            r_read_addr <= 0;
          else
            r_read_addr <= r_read_addr + 1;
          end if;
        when s_Read_Delay =>
          o_valid <= '0';
          r_read_addr <= r_read_addr + 1;
          if r_read_addr = 1 then
            o_start <= '1';
            r_read_state <= s_Read_Idle;
          end if;
      end case;
    end if;
  end process;
  
  
  
end behave;

  
