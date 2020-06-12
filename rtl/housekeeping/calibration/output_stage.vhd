library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity output_stage is
  generic (
    g_WIDTH : natural;
    LOG2_FFT_LEN : integer := 11
    );
  port (
    i_clk : in std_logic;
    i_fft_ready : in std_logic;
    i_data_re : in std_logic_vector(g_WIDTH-1 downto 0);
    i_data_im : in std_logic_vector(g_WIDTH-1 downto 0);
    o_addr : out std_logic_vector(LOG2_FFT_LEN-1 downto 0);
    o_rearm : out std_logic
    );
end output_stage;

architecture behave of output_stage is
  type t_ram is array (2**LOG2_FFT_LEN - 1 downto 0) of std_logic_vector(g_WIDTH-1 downto 0);
  signal ram_re, ram_im: t_ram;

  type t_state is (s_Idle, s_Busy, s_Done);
  signal r_state : t_state := s_Idle;
  signal r_count : integer range 0 to 2 ** LOG2_FFT_LEN - 1 := 0;
  
  
  signal sample_count : integer range 0 to LOG2_FFT_LEN := 0;
  signal bit_count    : integer range 0 to 31 := 0;
begin

  o_addr <= std_logic_vector(to_unsigned(r_count, o_addr'length));
  p_write : process(i_clk) is
  begin
    if rising_edge(i_clk) then
      case r_state is

        when s_Idle =>
          o_rearm <= '0';
          if i_fft_ready = '1' then
            r_state <= s_Busy;
            r_count <= 0;
          end if;

        when s_Busy =>
          ram_re(r_count) <= i_data_re;
          ram_im(r_count) <= i_data_im;
          if r_count = 2 ** LOG2_FFT_LEN - 1 then
            r_count <= 0;
            r_state <= s_Done;
            o_rearm <= '1';
          else
            r_count <= r_count + 1;
          end if;

        when s_Done =>
          o_rearm <= '0';
          if i_fft_ready = '0' then
            r_State <= s_Idle;
          end if;
      end case;
    end if;
  end process;
  
  
   
  
end behave;


