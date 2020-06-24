library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.common.all;

entity read_sequence is
  generic (
    --g_NUM_WORDS : natural -- number of 8-bit words in the sequence
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
    o_addr     : out std_logic_vector(7 downto 0) := (others => '0');
    o_done     : out std_logic
    );
end read_sequence;


architecture behave of read_sequence is
  -- these attribute appear to be ignored when applied to a signal
  -- but defining them on the entire architecture has the desired effect
  attribute syn_ramstyle : string;
  attribute syn_ramstyle of behave : architecture is "registers";

  attribute syn_romstyle : string;
  attribute syn_romstyle of behave : architecture is "logic";
  
  type t_state is (s_Idle, s_Load, s_Data, s_Delay, s_Done);

--  signal r_SEQ_DATA : t_i2c_data := g_SEQ_DATA;
--  --attribute syn_romstyle : string;
--  attribute syn_romstyle of r_SEQ_DATA : signal is "logic";
--  --attribute syn_romstyle of r_SEQ_DATA : signal is "EBR";
--  
--  --attribute syn_ramstyle : string;
--  attribute syn_ramstyle of r_SEQ_DATA : signal is "registers";
--  --attribute syn_ram_style of r_SEQ_DATA : signal is "distributed";
--  --attribute syn_ram_style of r_SEQ_DATA : signal is "block_ram";

  
  signal r_state : t_state := s_Idle;
  signal r_count : natural range 0 to 1+g_SEQ_DATA'length;
  constant c_DELAY : natural := 200;
  signal r_delay_count : natural range 0 to c_DELAY-1 := 0;
  signal test_count : std_logic_vector(num_bits(1+g_SEQ_DATA'length) downto 0);

begin
  test_count <= std_logic_vector(to_unsigned(r_count, test_count'length));
  --o_done <= '1' when r_state = s_Done else '0';

  process(i_clk) is
  begin
    if rising_edge(i_clk) then
      case r_state is
        when s_Idle =>
          o_done <= '1';
          if i_trig = '1' then
            o_done <= '0';
            r_state <= s_Load;
            r_count <= 0;
          end if;
        when s_Load =>
          r_state <= s_Data;
          o_valid <= '1';
          o_data  <= g_SEQ_DATA(r_count).data;
          o_dir <= g_SEQ_DATA(r_count).dir;
          o_restart <= g_SEQ_DATA(r_count).restart;
        when s_Data =>
          -- the data lines are abused to store the target addr in case of a read
          o_addr <= g_SEQ_DATA(r_count).data;
          if i_next = '1' then
            r_count <= r_count + 1;
            o_valid <= '0';
            if r_count = g_SEQ_DATA'length-1 then
              r_state <= s_Done;
            else
              if g_SEQ_DATA(r_count).delay = '1' then
                r_state <= s_Delay;
              else
                r_state <= s_Load;
              end if;
            end if;
          end if;
        when s_Delay =>
          if r_delay_count = c_DELAY - 1 then
            r_delay_count <= 0;
            r_state <= s_Load;
          else
            r_delay_count <= r_delay_count + 1;
          end if;
        when s_Done =>
          -- make sure we don't immediately retrigger if the trig stays high
          -- for a bit
          if i_trig = '0' then
            r_state <= s_Idle;
          end if;
      end case;
    end if;
  end process;
end behave;

