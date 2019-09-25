library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
--use work.common.all;

entity i2c is
  port(
    -- inputs:
    i_clk      : in std_logic;
    i_data     : in std_logic_vector(7 downto 0);
    i_dir      : in std_logic; -- '0' for read, '1' for write
    i_ack      : in std_logic; -- value of ack when dir='0', ignored when dir='1'
    i_restart  : in std_logic; -- should send Sr between previous word
    i_valid    : in std_logic; -- present data should be sent
    -- outputs:
    o_data      : out std_logic_vector (7 downto 0);
    o_datavalid : out std_logic;
    o_next      : out std_logic := '0';
    o_error     : out std_logic; -- TODO: assign this and abort if there is one
    -- i2c interface:
    sda	  : inout std_logic;
    scl	  : inout std_logic
    );
end  i2c;

architecture behave of i2c is
  type t_State is (s_Idle, s_Data, s_Ack, s_Stop);
  -- variables:
  signal r_State : t_State := s_Idle;
  signal r_count : natural range 0 to 8 := 0;
  signal r_data  : std_logic_vector(7 downto 0);
  signal r_dir   : std_logic;
  signal r_ack   : std_logic;
  signal r_sda   : std_logic := '1';
  signal r_scl   : std_logic := '1';

  -- just for debugging
  signal test_count : std_logic_vector(3 downto 0);

begin

  -- assign tri-state outputs
  scl <= 'Z' when r_scl = '1' else '0';
  sda <= 'Z' when r_sda = '1' else '0';

  -- assign count to vector for debug
  test_count <= std_logic_vector(to_unsigned(r_count, test_count'length));

  
  process(i_clk) is
  begin
    if rising_edge(i_clk) then
      case r_state is
        when s_Idle =>
          -- clear next request output
          o_next <= '0';
          -- check if next word should start
          if i_valid = '1' then
            -- latch the inputs
            r_data <= i_data;
            r_dir <= i_dir;
            r_ack <= i_ack;
            -- reset counter
            r_count <= 0;
            -- create START condition
            r_sda <= '0';
            -- proceed to Data state
            r_state <= s_Data;
          else
            --r_sda <= '1';
          end if;
        when s_Data =>
          if scl /= '0' then
            -- create a falling edge
            r_scl <= '0';
            -- write data if we should
            if r_dir = '0' then
              r_sda <= r_data(7-r_count);
            else
              r_sda <= '1';
            end if;
          else
            -- create rising edge
            r_scl <= '1';
            -- increment bit counter
            r_count <= (r_count + 1);
            -- request next word when nearly done
            if r_count = 6 then
              o_next <= '1';
            end if;
            -- when done -> proceed to ack state
            if r_count = 7 then
              r_state <= s_Ack;
              o_next <= '0';
            end if;
            -- read in data bit
            if r_dir = '1' then
              if sda = '0' then
                o_data(7-r_count) <= '0';
              else
                o_data(7-r_count) <= '1';
              end if;
              if r_count = 7 then
                o_datavalid <= '1';
              end if;
            end if;
          end if;
        when s_Ack =>
          o_datavalid <= '0';
          if scl /= '0' then
            -- create falling edge
            r_scl <= '0';
            -- process ack:
            if r_dir = '1' then
              r_sda <= r_ack; -- in read mode we transmit the ack bit
            else
              r_sda <= '1'; -- accept ack bit
            end if;
          else
            -- create rising edge:
            r_scl <= '1';
            if i_valid = '1' and  i_restart = '0' then
              -- continue with next byte
              r_state <= s_Data;
              r_data <= i_data;
              r_dir <= i_dir;
              r_ack <= i_ack;
              r_count <= 0;
            else
              r_state <= s_Stop;
              -- there may be data after the restart in which case we need to
              -- release sda now. otherwise we pull low to make sure the stop
              -- is after the last clock rise.
              --if i_valid = '1' then
              --  r_sda <= '1';
              --else
              --  r_sda <= '0';
              --end if;
            end if;
            -- check that there is ack
            if sda = '1' then
              -- TODO: raise error
            end if;
          end if;
        when s_Stop =>
          if i_valid = '1' then
            r_sda <= '1';
          else
            r_sda <= '0';
          end if;
          if scl /= '0' then
            r_scl <= '0';
          else
            r_scl <= '1';
            r_state <= s_Idle;
          end if;
      end case;
    end if;
  end process;
  
end behave;

