library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- The uart receiver must deserialize incomming data at a 115200 baud. It
-- does so by oversampling the data signal. After receiving the stop bit the
-- module will wait for the next high-low transition to prevent clock-skew from
-- propagating.
--
--
entity uart_rx is
  generic (
    g_BAUD_DIVIDER: natural := 434
    );

  port (
    i_data : in std_logic;
    i_sample_clk : in std_logic;
    o_data: out std_logic_vector(7 downto 0);
    o_datavalid: out std_logic := '0'
    );
end uart_rx;

architecture behavior of uart_rx is
  type t_State is (s_Idle, s_Start, s_Data, s_Stop);
  -- short explanation: start, stop and data indicate which bit we are in.
  signal r_State : t_State := s_Idle;
  signal r_Count : natural range 0 to g_BAUD_DIVIDER-1  := 0;
  signal r_Bitnum : natural range 0 to 7 := 0;
  signal r_input_buffer_1 : std_logic := '0';
  signal r_input_buffer_2 : std_logic := '0';

begin
 
  process (i_sample_clk)
  begin
    
  end process;
  
  process(i_sample_clk)
  begin
    if  rising_edge(i_sample_clk) then
      r_input_buffer_1 <= i_data;
      r_input_buffer_2 <= r_input_buffer_1;
    end if;
  
    if rising_edge(i_sample_clk) then
      case r_State is
        when s_Idle =>
          --o_datavalid <= '0';
          if r_input_buffer_2 = '0' then
            -- start bit received
            r_Count <= 0;
            r_State <= s_Start;
            o_datavalid <= '0';
            o_data <= (others=>'0');
          else
            -- here we continue counting until we can clear o_datavalid
            -- we keep o_datavalid high for 1.5 baud clock cycles.
            -- This guarantees that the controller, which runs on it's own baud
            -- clock that may be slightly faster or slower, sees it at least
            -- once.
            r_State <= s_Idle;
            if r_Count = g_BAUD_DIVIDER-1 then
              o_datavalid <= '0';
            else
              r_Count <= r_Count + 1;  
            end if;
            
          end if;
        when s_Start =>
          --o_datavalid <= '0';
          if r_Count = g_BAUD_DIVIDER-1 then
            r_State <= s_Data;
            r_Bitnum <= 0;
            r_Count <= 0;
          else
            r_Count <= r_Count + 1;
            r_State <= s_Start;
          end if;
        when s_Data =>
          if r_Count = g_BAUD_DIVIDER-1 then
            r_Count <= 0;
            if r_Bitnum = 7 then
              r_State <= s_Stop;
              --o_datavalid <= '1';
            else
              r_Bitnum <= r_Bitnum + 1;
            end if;
          else
            r_Count <= r_Count+1;
            if r_Count = g_BAUD_DIVIDER/2 then
              -- capture a bit
              o_data(r_Bitnum) <= r_input_buffer_2;
              if r_Bitnum = 7 then
                o_datavalid <= '1';
              end if;
            end if;
            
          end if;
          
        when s_Stop =>
          --o_datavalid <= '0';
          if r_Count = g_BAUD_DIVIDER / 2 then
            -- I stop half a cycle too early
            -- this ensures that some part of the stop bit is received
            -- but if the clock has skewed forward a little this makes the
            -- uart receptable for the next start bit.
            r_State <= s_Idle;
            --o_datavalid <= '1';
            --r_Count <= 0;
          else
            r_Count <= r_Count +1;
          end if;
          
      end case;
    end if;
  end process;

end;

  
