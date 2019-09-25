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
    i_data     : in std_logic_vector(7 downto 0);
    i_rw       : in std_logic;
    i_restart  : in std_logic;
    i_valid    : in std_logic;
    --i_numbytes : in std_logic_vector(c_I2C_MAXBYTES_BITS-1 downto 0);
    
    --outputs
    o_data      : out std_logic_vector (7 downto 0);
    o_datavalid : out std_logic := '0';
    o_next      : out std_logic := '0';
    
    -- i2c interface
    sda	  : inout std_logic;
    scl	  : inout std_logic
    );
end  i2c2;

architecture behave of i2c2 is
  type t_State is (s_Idle, s_Addr, s_Rw, s_AddrAck, s_Data, s_DataAck, s_Stop);
  -- variables:
  signal r_State : t_State := s_Idle;
  signal r_count : natural range 0 to 8 := 0;

  signal r_data : std_logic_vector(7 downto 0);
  signal r_rw   : std_logic;

  signal test_count : std_logic_vector(num_bits(8) downto 0);

  signal r_sda : std_logic := '1';
  signal r_scl : std_logic := '1';

  
begin

  scl <= 'Z' when r_scl = '1' else '0';
  sda <= 'Z' when r_sda = '1' else '0';
  
  test_count <= std_logic_vector(to_unsigned(r_count, test_count'length));

  
  process(i_clk) is
  begin
    if rising_edge(i_clk) then
      case r_state is
        when s_Idle =>
          o_next <= '0';
          if i_valid = '1' then
            r_data <= i_data;
            r_rw <= i_rw;
            r_count <= 0;
            r_sda <= '0';
            r_state <= s_Addr;
          else
            r_sda <= '1';
          end if;
        when s_Addr =>
          if scl = '0' then
            r_scl <= '1';
            r_count <= r_count + 1;
            if r_count = g_ADDR'length-1 then
              r_State <= s_Rw;
            end if;
          else
            r_scl <= '0';
            if g_ADDR(g_ADDR'length-r_count-1) = '1' then
              r_sda <= '1';
            else
              r_sda <= '0';
            end if;
          end if;
        when s_Rw =>
          if scl = '0' then
            r_scl <= '1';
            r_state <= s_AddrAck;
          else
            r_scl <= '0';
            if r_rw = '0' then
              r_sda <= '0';
            else
              r_sda <= '1';
            end if;
          end if;
        when s_AddrAck =>
          if scl = '0' then
            r_scl <= '1';
            r_state <= s_Data;
            r_count <= 0;
            if sda = '1' then
              -- TODO: raise error
            end if;
          else
            r_scl <= '0';
            r_sda <= '1';
          end if;
        when s_Data =>
          if scl = '0' then
            r_scl <= '1';
            r_count <= (r_count + 1) ;
            if r_count = 6 then
              o_next <= '1';
            end if;
            if r_count = 7 then
              r_state <= s_DataAck;
              o_next <= '0';
            end if;
            -- read in data bit
            if r_rw = '1' then
              o_data(7-r_count) <= sda;
              if r_count = 7 then
                o_datavalid <= '1';
              end if;
            end if;
          else
            r_scl <= '0';
            --report "r_count: " & integer'image(r_count);
            --report "index: " & integer'image(to_integer(unsigned(i_numbytes)) * 8 - r_count - 1);
            if r_rw = '1' or r_data(7 - r_count) = '1' then
              r_sda <= '1';
            else
              r_sda <= '0';
            end if;
          end if;
        when s_DataAck =>
          o_datavalid <= '0';
          if scl = '0' then
            r_scl <= '1';
            if i_valid = '1' and  i_restart = '0' then
              -- continue with next byte
              r_state <= s_Data;
              r_data <= i_data;
              r_rw <= i_rw;
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
          else
            r_scl <= '0';
            if r_rw = '1' then
              r_sda <= '0'; -- transmit ack
            else
              r_sda <= '1'; -- accept ack bit
            end if;
          end if;
        when s_Stop =>
          if i_valid = '1' then
            r_sda <= '1';
          else
            r_sda <= '0';
          end if;
          if scl = '1' then
            r_scl <= '0';
          else
            r_scl <= '1';
            r_state <= s_Idle;
          end if;
      end case;
    end if;
  end process;
  
end behave;

