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
    o_rw       : out std_logic;
    o_restart  : out std_logic;
    o_valid    : out std_logic;
    o_addr     : out std_logic_vector(2 downto 0)
    );
end read_sequence;

architecture behave of read_sequence is
  type t_state is (s_Idle, s_Load, s_Data, s_Done);
  
  signal r_state : t_state := s_Idle;
  signal r_count : natural range 0 to 1+g_SEQ_DATA'length;
  signal test_count : std_logic_vector(num_bits(1+g_SEQ_DATA'length) downto 0);
  
begin
  test_count <= std_logic_vector(to_unsigned(r_count, test_count'length));

  process(i_clk) is
  begin
    if rising_edge(i_clk) then
      case r_state is
        when s_Idle =>
          if i_trig = '1' then
            r_state <= s_Load;
            r_count <= 0;
          end if;
        when s_Load =>
          r_state <= s_Data;
          o_valid <= '1';
          o_data  <= g_SEQ_DATA(r_count).data;
          o_rw <= g_SEQ_DATA(r_count).rw;
          o_restart <= g_SEQ_DATA(r_count).restart;
          --o_addr <= g_SEQ_DATA(r_count).addr;
        when s_Data =>
          o_addr <= g_SEQ_DATA(r_count).addr;
          if i_next = '1' then
            r_count <= r_count + 1;
            o_valid <= '0';
            if r_count = g_SEQ_DATA'length-1 then
              r_state <= s_Done;
            else
              r_state <= s_Load;
            end if;
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

