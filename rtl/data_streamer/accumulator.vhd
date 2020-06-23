library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity accumulator is
  generic (
    g_WIDTH : natural;
    g_LENGTH: natural);
  port (
    i_clk  : in std_logic;
    i_data_even: in std_logic_vector(g_WIDTH-1 downto 0);
    i_data_odd: in std_logic_vector(g_WIDTH-1 downto 0);
    o_clk : out std_logic;
    o_data_even: out std_logic_vector(g_WIDTH-1 downto 0) := (others => '0');
    o_data_odd: out std_logic_vector(g_WIDTH-1 downto 0) := (others => '0')
    );
end accumulator;

architecture behave of accumulator is
  constant max_in : integer := 2**(g_WIDTH-1)-1;
  constant min_in : integer := -(2**(g_WIDTH-1));
  -- max sum is two times extra that because ghdl checks the range for statements that
  -- aren't the last assignment to a signal
  constant max_sum : integer :=  (2 + g_LENGTH) * max_in;
  constant min_sum : integer :=  (2 + g_LENGTH) * min_in;


  signal r_count : natural range 0 to g_LENGTH-1 := 0;
  signal r_sum_even, r_sum_odd : integer range min_sum to max_sum := 0;

  
begin

  process(i_clk) is
  begin

    if rising_edge(i_clk) then
      r_count <= (r_count + 1) mod g_LENGTH;

      -- accumulate in the right sums:
      if r_count < (g_LENGTH)/2 then
        r_sum_even <= r_sum_even +
                      to_integer(signed(i_data_even)) +
                      to_integer(signed(i_data_odd));
      elsif r_count > (g_LENGTH-1)/2 then
        r_sum_odd <= r_sum_odd +
                     to_integer(signed(i_data_even)) +
                     to_integer(signed(i_data_odd));
      else
        r_sum_even <= r_sum_even + to_integer(signed(i_data_even));
        r_sum_odd  <= r_sum_odd  + to_integer(signed(i_data_odd));
      end if;

      -- reset and output      
      if r_count = 0 then
        if r_sum_even < min_in then
          o_data_even <= std_logic_vector(to_signed(min_in, g_WIDTH));
        elsif r_sum_even > max_in then
          o_data_even <= std_logic_vector(to_signed(max_in, g_WIDTH));
        else
          o_data_even <= std_logic_vector(to_signed(r_sum_even, g_WIDTH));
        end if;
        
        if r_sum_odd < min_in then
          o_data_odd <= std_logic_vector(to_signed(min_in, g_WIDTH));
        elsif r_sum_odd > max_in then
          o_data_odd <= std_logic_vector(to_signed(max_in, g_WIDTH));
        else
          o_data_odd <= std_logic_vector(to_signed(r_sum_odd, g_WIDTH));
        end if;
        
        r_sum_even <= to_integer(signed(i_data_even)) +
                      to_integer(signed(i_data_odd));
        r_sum_odd <= 0;
      end if;

      -- generate output clock
      if r_count = 0 then
        o_clk <= '1';
      end if;
      if r_count = g_LENGTH / 2 then
        o_clk <= '0';
      end if;

    end if;
  end process;
  

  
end behave;

  
    
      
