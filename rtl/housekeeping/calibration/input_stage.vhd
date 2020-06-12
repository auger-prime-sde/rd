library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- The input stage is responsible for slicing quiet areas is the time domain,
-- for keeping track of rolling mean and rms, for buffering the input, and for
-- signalling the fft engine to start when the buffer is full.


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
      o_data_even : out std_logic_vector(g_ADC_BITS-1 downto 0);
      o_data_odd  : out std_logic_vector(g_ADC_BITS-1 downto 0);
      i_rearm     : in std_logic
      );
end input_stage;


architecture behave of input_stage is

  attribute syn_ramstyle : string;
  attribute syn_ramstyle of behave : architecture is "block_ram";

  signal mean_ns, mean_ew : integer range -(2 ** (g_ADC_BITS - 1)) to 2 ** (g_ADC_BITS - 1) - 1;
  signal r_corrected_ns_even, r_corrected_ns_odd, r_corrected_ew_even, r_corrected_ew_odd : integer range -(2 ** (g_ADC_BITS - 1)) to 2 ** (g_ADC_BITS - 1) - 1;
  signal w_write_data : std_logic_vector(2 * g_ADC_BITS - 1 downto 0);
  
  --
  signal r_input_select : std_logic := '0';
  signal w_valid, w_valid_ns, w_valid_ew : std_logic; -- indicates that all values are inside the threshold range.

  
  -- write controller
  type t_write_state is (s_Write_Busy, s_Write_Idle);
  signal r_write_state : t_write_state := s_Write_Busy;
  --signal r_write_addr : std_logic_vector(LOG2_FFT_LEN - 1 downto 0) := (others => '0');
  signal r_write_addr : integer range 0 to 2 ** LOG2_FFT_LEN - 1 := 0;

  -- read controller
  type t_read_state is (s_Read_Idle, s_Read_Busy, s_Read_Delay);
  signal r_read_state : t_read_state := s_Read_Idle;
  --signal r_read_addr : std_logic_vector(LOG2_FFT_LEN - 1 downto 0) := (others => '0');
  signal r_read_addr : integer range 0 to 2 ** LOG2_FFT_LEN - 1 := 0;


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

--  component native_buffer is
--	port (
--      WrAddress: in  std_logic_vector(9 downto 0); 
--      RdAddress: in  std_logic_vector(9 downto 0); 
--      Data: in  std_logic_vector(23 downto 0); 
--      WE: in  std_logic; 
--      RdClock: in  std_logic; 
--      RdClockEn: in  std_logic; 
--      Reset: in  std_logic; 
--      WrClock: in  std_logic; 
--      WrClockEn: in  std_logic; 
--      Q: out  std_logic_vector(23 downto 0)
--      );
--  end component;
--

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
      g_AVG_NUM_BITS => 3
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
      g_AVG_NUM_BITS => 3
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

  --sync_rearm : sync_1bit
  --  port map (
  --    i_clk  => i_data_clk,
  --    i_data => rearm,
  --    o_data => rearm_sync
  --    );

  --r_rdaddress <= "" & r_read_addr;
--  input_buffer : native_buffer
--    port map (
--      WrAddress => "000000" & r_write_addr,
--      RdAddress => "000000" & r_read_addr,
--      Data      => i_data_ns_odd & i_data_ew_odd & i_data_ns_even & i_data_ew_even,
--      WE        => r_write_enable,
--      RdClock   => i_clk,
--      RdClockEn => '0',
--      Reset     => '0',
--      WrClock   => i_clk,
--      WrClockEn => '1',
--      Q(2 * g_ADC_BITS - 1 downto g_ADC_BITS) => o_data_ns,
--      Q(    g_ADC_BITS - 1 downto          0) => o_data_ew
--      );
--        



--  r_write_enable <= '1' when w_valid = '1' and r_write_state = s_write_busy else '0';
      
  r_corrected_ns_even <= to_integer(signed(i_data_ns_even)) - mean_ns;
  r_corrected_ns_odd  <= to_integer(signed(i_data_ns_odd )) - mean_ns;
  r_corrected_ew_even <= to_integer(signed(i_data_ew_even)) - mean_ew;
  r_corrected_ew_odd  <= to_integer(signed(i_data_ew_odd )) - mean_ew;


  w_valid_ns <= '1' when (
    (
      r_corrected_ns_odd > -QUIET_THRESHOLD and r_corrected_ns_odd < QUIET_THRESHOLD
    ) and (
      r_corrected_ns_even > -QUIET_THRESHOLD and r_corrected_ns_even < QUIET_THRESHOLD
    )
  ) else '0';
  w_valid_ew <= '1' when (
    (
      r_corrected_ew_odd > -QUIET_THRESHOLD and r_corrected_ew_odd < QUIET_THRESHOLD
    ) and (
      r_corrected_ew_even > -QUIET_THRESHOLD and r_corrected_ew_even < QUIET_THRESHOLD
    )
  ) else '0';
  w_valid <= w_valid_ns when r_input_select = '0' else w_valid_ew;
  w_write_data <= i_data_ns_even & i_data_ns_odd when r_input_select = '0' else i_data_ew_even & i_data_ew_odd;

  
  -- input buffer stage. We use a linear buffer, whenever the input is outside
  -- the threshold area we reset the counter. when the counter hits the end of
  -- the buffer we trigger the output and restart.
  p_write : process(i_data_clk) is -- 125 MHz
  begin
    if rising_edge(i_data_clk) then
      case r_write_state is
        when s_Write_Busy =>
          buffer_full <= '0';
          if w_valid = '1' then
            ram(r_write_addr) <= w_write_data;
            
            -- check if done, else increment
            if r_write_addr = 2 ** LOG2_FFT_LEN - 1 then
              r_write_addr <= 0;
              r_write_state <= s_Write_Idle;
              buffer_full <= '1';
            else
              r_write_addr <=  r_write_addr + 1;
            end if;
          else
            -- reset
            r_write_addr <= 0;
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
  p_read : process (i_fft_clk) is -- 100 MHz
  begin
    if rising_edge(i_fft_clk) then
      o_addr <= std_logic_vector(to_unsigned(r_read_addr, o_addr'length));
      case r_read_state is
        when s_Read_Idle =>
          o_valid <= '0';
          o_start <= '0';
          r_read_addr <= 0;
          if buffer_full_sync = '1' then
            r_read_state <= s_Read_Busy;
          end if;
        when s_Read_Busy =>
          o_valid <= '1';
          o_start <= '0';
          o_data_even <= ram(r_read_addr)(2*g_ADC_BITS-1 downto g_ADC_BITS);
          o_data_odd  <= ram(r_read_addr)(  g_ADC_BITS-1 downto          0);
          if r_read_addr = 2 ** LOG2_FFT_LEN - 1 then
            r_read_state <= s_Read_Delay;
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

  
