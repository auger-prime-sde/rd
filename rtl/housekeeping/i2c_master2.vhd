LIBRARY ieee;
USE ieee.std_logic_1164.all;
use IEEE.numeric_std.all;


entity i2c_master2 is
  port(
    i_clk     : in std_logic;
    i_enable  : in std_logic;
    i_address : in std_logic_vector(6 downto 0);
    i_rw      : in std_logic;
    i_data    : in std_logic_vector(7 downto 0);
    o_busy    : out std_logic;
    o_data    : out std_logic_vector(7 downto 0);
    o_scl     : out std_logic := '1';
    io_sda    : inout std_logic := '1'

    );
end i2c_master2;
  
architecture behave of i2c_master2 is
  type t_state is (s_Idle, s_Start, s_Addr, s_Rw, s_AckAddr, s_Data, s_AckData, s_Stop);
  signal r_state : t_state := s_Idle;
  signal r_rw : std_logic;
  signal r_count : natural range 0 to 32 := 0;
  signal o_err : std_logic;
  signal r_data : std_logic_vector(7 downto 0);
begin

  process (i_clk) is
  begin
    if rising_edge(i_clk) then
      case r_state is
        when s_Idle =>
          if i_enable = '1' then
            r_state <= s_Start;
            r_data <= i_data;
            r_rw <= i_rw;
            --o_scl <= '0';
            io_sda <= '0';
            o_busy <= '1';
            r_count <= 0;
          end if;
        when s_Start =>
          r_count <= r_count + 1;
          -- keep clock high for one cycle to make sure the falling sda is
          -- 'during' clock high
          if r_count = 0 then
            o_scl <= '1';
          else
            o_scl <= '0';
          end if;
          
          if r_count = 3 then
            r_state <= s_Addr;
            r_count <= 0;
          end if;
        when s_Addr =>
          r_count <= r_count + 1;
          case i_address(6-r_count/4) is
            when '0' => io_sda <= '0';
            when others => io_sda <= 'Z';
          end case;
          if r_count mod 4 = 1 then
            o_scl <= '1';
          else
            o_scl <= '0';
          end if;
          if r_count = 27 then
            r_state <= s_Rw;
            r_count <= 0;
          end if;
        when s_Rw =>
          r_count <= r_count + 1;
          case r_rw is
            when '0' => io_sda <= '0';
            when others => io_sda <= 'Z';
          end case;
          if r_count mod 4 = 1 then
            o_scl <= '1';
          else
            o_scl <= '0';
          end if;
          if r_count = 3 then
            r_state <= s_AckAddr;
            r_count <= 0;
            io_sda <= 'Z';
          end if;
        when s_AckAddr =>
          r_count <= r_count + 1;
          io_sda <= 'Z';
          if r_count mod 4 = 1 then
            o_scl <= '1';
          else
            o_scl <= '0';
          end if;
          if r_count = 2 and io_sda /= '0' then
            o_err <= '1';
          end if;
          if r_count = 3 then
            r_state <= s_Data;
            r_count <= 0;
          end if;
        when s_Data =>
          o_busy <= '1';
          r_count <= (r_count+1);
          if r_rw = '0' then
            case r_data(7-r_count/4) is
              when '0' => io_sda <= '0';
              when others => io_sda <= 'Z';
            end case;
          end if;
          if r_count mod 4 = 2 then
            o_data(7-r_count/4) <= io_sda;
          end if;
          if r_count mod 4 = 1 then
            o_scl <= '1';
          else
            o_scl <= '0';
          end if;
          if r_count = 31 then
            r_state <= s_AckData;
            r_data <= i_data;
            r_count <= 0;
            --o_busy <= '0';
          end if;
          --o_busy <= '1';
        when s_AckData =>
          r_count <= r_count + 1;
          if r_rw = '0' then
            io_sda <= 'Z';
            if r_count = 2 and io_sda /= '0' then
              o_err <= '1';
            end if;
          else
            io_sda <= '0';
          end if;
          
          if r_count mod 4 = 1 then
            o_scl <= '1';
          else
            o_scl <= '0';
          end if;
          --o_busy <= '0';
          if r_count = 3 then
            o_busy <= '0';
            if i_enable = '1' then
              r_state <= s_Data;
              if r_rw = '1' then -- todo: is this check needed?
                io_sda <= 'Z';
              end if;
              r_count <= 0;
              --o_busy <= '1';
            else
              r_state <= s_Stop;
              r_count <= 0;
            end if;
          end if;
        when s_Stop =>
          o_scl <= '1';
          r_count <= r_count + 1;
          if r_count mod 4 = 1 then
            io_sda <= 'Z';
          end if;
          if r_count = 3 then
            r_State <= s_Idle;
            r_count <= 0;
          end if;
          
          
          
      end case;
    end if;
    
  end process;
  

end behave;
  
