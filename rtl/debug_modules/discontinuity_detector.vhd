library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity discontinuity_detector is
  generic (
    g_SIZE : natural := 12;
    g_THRES : natural := 45
    );
  port (
    i_data: in std_logic_vector(g_SIZE-1 downto 0);
    i_clk: in std_logic;
    i_rst: in std_logic;
    o_fault : out std_logic
    );
end discontinuity_detector;

architecture behavior of discontinuity_detector is
  -- state machine type:
  type t_State is (s_Idle, s_Busy); -- in Idle we are waiting for the first and
                                    -- should not trigger when the next arrives.
  -- variables:
  signal r_State : t_State := s_Idle;
  signal r_previous: std_logic_vector(g_SIZE-1 downto 0) := (others=>'0');
  signal r_diff : std_logic_vector(g_SIZE-1 downto 0) := (others=>'0');
	
begin
  
  process(i_clk)
  begin
    if rising_edge(i_clk) then
      if i_rst = '1' then
        r_State <= s_Idle;
      else
        r_State <= s_Busy;
      end if;

      
      if (r_State = s_Busy) and  (abs(signed(i_data)-signed(r_previous)) > g_THRES) then
        o_fault <= '1';
      else
        o_fault <= '0';
      end if;
        
      r_previous <= i_data;

    end if;
    
  end process;
  r_diff <= std_logic_vector( abs(signed(i_data)-signed(r_previous)));
end;

    
