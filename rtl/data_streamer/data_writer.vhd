library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- writes out two data channels simultaneously over two lines for the two channels.
-- it writes one extra (13th) bit after each sample that is the parity bit
entity data_writer is
  generic (
    g_WORDSIZE : natural := 12;
    g_TARGET_PARITY : std_logic := '1'
    );
  port (
    -- inputs
    i_data        : in std_logic_vector(2*g_WORDSIZE-1 downto 0);
    i_dataready   : in std_logic;
    i_clk         : in std_logic;
    i_clk_padding : in std_logic;
    -- outputs
    o_data_1      : out std_logic := '1';
    o_data_2      : out std_logic := '1';
    o_clk         : out std_logic
    );
end data_writer;


architecture behave of data_writer is
  -- state machine type:
  type t_State is (s_Idle, s_Busy, s_Parity);
  -- variables:
  signal r_State : t_State := s_Idle;
  signal r_Count : natural range 0 to g_WORDSIZE-1 := 0;
  signal r_Buffer : std_logic_vector(2*g_WORDSIZE-1 downto 0) := (others => '0');
  signal r_Parity_1 : std_logic := g_TARGET_PARITY;
  signal r_Parity_2 : std_logic := g_TARGET_PARITY;

begin

  o_clk <= not i_clk when r_state /= s_Idle or i_clk_padding = '1' else '1';

  p_tx : process(i_clk) is
  begin
    if rising_edge(i_clk) then
      case r_state is
        when s_Idle =>
          if i_dataready = '1' then
            r_state <= s_Busy;
            r_buffer <= i_data;
            r_count <= 0;
          end if;
          o_data_1 <= '1';
          o_data_2 <= '1';
        when s_Busy =>
          -- go to next state
          if r_count = g_WORDSIZE - 1 then
            r_state <= s_Parity;
          else
            --increment counter
            r_count <= r_count + 1;
          end if;
          -- output data
          o_data_1 <= r_Buffer(g_WORDSIZE - r_Count - 1);
          o_data_2 <= r_Buffer(2*g_WORDSIZE - r_Count - 1);
          -- record parity
          r_Parity_1 <= r_Parity_1 xor r_Buffer(g_WORDSIZE - r_Count - 1);
          r_Parity_2 <= r_Parity_2 xor r_Buffer(2*g_WORDSIZE - r_Count - 1);
        when s_Parity =>
          --output
          o_data_1 <= r_Parity_1;
          o_data_2 <= r_Parity_2;
          -- reset parity registers
          r_Parity_1 <= g_TARGET_PARITY;
          r_Parity_2 <= g_TARGET_PARITY;
          -- decide what comes next
          if i_dataready = '1' then
            -- start again
            r_count <= 0;
            r_state <= s_Busy;
            r_buffer <= i_data;
          else
            -- back to idle
            r_state <= s_Idle;
          end if;
      end case;
    end if;
  end process;
    
end behave;
