library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.common.all;

entity i2c2 is
  generic (
    g_ADDR          : std_logic_vector(6 downto 0)
    );
  port(	--inputs
    i_clk      : in std_logic;
    i_data     : in t_i2c_word;
    i_valid    : in std_logic;
    --i_numbytes : in std_logic_vector(c_I2C_MAXBYTES_BITS-1 downto 0);
    
    --outputs
    o_data  : out std_logic_vector (7 downto 0); 
    o_next  : out std_logic := '0';
    
    -- i2c interface
    sda	  : inout std_logic := 'Z';
    scl	  : inout std_logic := 'Z'
    );
end  i2c2;

architecture behave of i2c2 is
  type t_State is (s_Idle, s_Start, s_Addr, s_Rw, s_AddrAck, s_Data, s_DataAck, s_Stop);
  -- variables:
  signal r_State : t_State := s_Idle;
  signal r_count : natural range 0 to 8 := 0;

  signal r_data : t_i2c_word;

  signal test_count : std_logic_vector(num_bits(8) downto 0);
    
begin
  test_count <= std_logic_vector(to_unsigned(r_count, test_count'length));
  process(i_clk) is
  begin
    if rising_edge(i_clk) then
      case r_state is
        when s_Idle =>
          o_next <= '0';
          if i_valid = '1' then
            r_data <= i_data;
            r_count <= 0;
            sda <= '0';
            r_state <= s_Addr;
          end if;
        when s_Start =>
          r_state <= s_Addr;
          scl <= '0';
        when s_Addr =>
          if scl = '0' then
            scl <= 'Z';
            r_count <= r_count + 1;
            if r_count = g_ADDR'length-1 then
              r_State <= s_Rw;
            end if;
          else
            scl <= '0';
            if g_ADDR(g_ADDR'length-r_count-1) = '1' then
              sda <= 'Z';
            else
              sda <= '0';
            end if;
          end if;
        when s_Rw =>
          if scl = '0' then
            scl <= 'Z';
            r_state <= s_AddrAck;
          else
            scl <= '0';
            if r_data.rw = '0' then
              sda <= '0';
            else
              sda <= 'Z';
            end if;
          end if;
        when s_AddrAck =>
          if scl = '0' then
            scl <= 'Z';
            r_state <= s_Data;
            r_count <= 0;
            if sda /= '0' then
              -- TODO: raise error
            end if;
          else
            scl <= '0';
            sda <= 'Z';
          end if;
        when s_Data =>
          if scl = '0' then
            scl <= 'Z';
            r_count <= (r_count + 1) ;
            if r_count = 6 then
              o_next <= '1';
            end if;
            if r_count = 7 then
              r_state <= s_DataAck;
              o_next <= '0';
            end if;
            -- read in data bit
            if r_data.rw = '1' then
              o_data(7-r_count) <= sda;
            end if;
          else
            scl <= '0';
            --report "r_count: " & integer'image(r_count);
            --report "index: " & integer'image(to_integer(unsigned(i_numbytes)) * 8 - r_count - 1);
            if r_data.rw = '1' or r_data.data(7 - r_count) = '1' then
              sda <= 'Z';
            else
              sda <= '0';
            end if;
          end if;
        when s_DataAck =>
          if scl = '0' then
            scl <= 'Z';
            if i_valid = '1' then
              if i_data.restart = '1' then
                r_state <= s_Idle;
              else
                r_state <= s_Data;
                r_data <= i_data;
                r_count <= 0;
              end if;
            else
              r_state <= s_Stop;
              sda <= '0'; -- drive low now so that releasing
                          -- it later creates a stop condition
            end if;
            if sda /= '0' then
              -- TODO: raise error
            end if;
          else
            scl <= '0';
            if r_data.rw = '1' then
              sda <= '0'; -- transmit ack
            else
              sda <= 'Z'; -- accept ack bit
            end if;
          end if;
        when s_Stop =>
          sda <= 'Z';
          r_state <= s_Idle;
          r_count <= 0;
          --o_next <= '1';
      end case;
    end if;
  end process;
  
end behave;

