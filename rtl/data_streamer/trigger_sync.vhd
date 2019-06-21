library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- block to ensure trigger pulses are exactly one clock pulse long and
-- registered to our clock.
-- introduces 1 extra delay because this is also the place where the trigger
-- signal is registered into out clock domain. 
entity trigger_sync is
  port (
    i_clk : in std_logic;
    i_trigger : in std_logic;
    o_trigger : out std_logic := '0'
    );
end trigger_sync;

architecture behave of trigger_sync is
  type t_state is (s_Idle, s_Pulse);
  signal r_state : t_state := s_Idle;
  signal r_trigger : std_logic;
begin

  process(i_clk) is
  begin

    if rising_edge(i_clk) then
      r_trigger <= i_trigger;
      case r_state is
        when s_Idle =>
          if r_trigger = '1' then
            o_trigger <= '1';
            r_state <= s_Pulse;
          end if;
        when s_Pulse =>
          o_trigger <= '0';
          if r_trigger = '0' then
            r_state <= s_Idle;
          end if;
      end case;
    end if;
  end process;
end behave;

