library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


-- test source generates a superposition of a triangle wave with pseudo random
-- pulses
entity test_source is
  generic (g_ADC_BITS : natural := 12);
  port (
    i_clk  : in std_logic;
    o_data_even : out std_logic_vector(g_ADC_BITS-1 downto 0) := (others => '0');
    o_data_odd  : out std_logic_vector(g_ADC_BITS-1 downto 0) := (others => '0')
    );
end test_source;

architecture behave of test_source is
  component triangle_source is
    generic (g_ADC_BITS : natural := 12);
    port (
      i_clk  : in std_logic;
      o_data_even : out std_logic_vector(g_ADC_BITS-1 downto 0) := (others => '0');
      o_data_odd  : out std_logic_vector(g_ADC_BITS-1 downto 0) := (others => '0')
      );
  end component;

  component lfsr is
    generic (
      SEED: std_logic_vector(14 downto 0)
      );
    port (
      clk : in std_logic;
      count : out std_logic_vector(14 downto 0)
      );
  end component;

  constant c_TRIANGLE_BITS : integer := 5; -- +/- 8
  -- we would like ~1 peak per 2048 samples, maybe a little less so we can also
  -- see occasionally two consecutive fft windows. r_random goes upto 32767.
  -- The threshold is checked only once every 15 cycles. So we want it to
  -- trigger ~1 in 200 times. So we set the threshold to 199/200 of 32767;
  --constant c_PEAK_THRES : natural :=  32604;
  constant c_PEAK_THRES : natural :=  31000;
  
  signal r_count : integer range 0 to 14;
  signal r_random_select, r_random_height : std_logic_vector(14 downto 0);
  signal r_triangle_even  : std_logic_vector(c_TRIANGLE_BITS-1 downto 0);
  signal r_triangle_odd : std_logic_vector(c_TRIANGLE_BITS-1 downto 0);
begin

  lfsr_1 : lfsr
    generic map (
      SEED => "000110100010111"
      )
    port map (
      clk => i_clk,
      count => r_random_select
      );

  lfsr_2 : lfsr
    generic map (
      SEED => "011010111011010"
      )
    port map (
      clk => i_clk,
      count => r_random_height
      );


  
  source : triangle_source
    generic map (
      g_ADC_BITS => c_TRIANGLE_BITS
      )
    port map (
      i_clk => i_clk,
      o_data_even => r_triangle_even,
      o_data_odd  => r_triangle_odd
      );
  
  process(i_clk) is
  begin
    if rising_edge(i_clk) then
      -- default behaviour, overridden below:
      o_data_even <= std_logic_vector(to_signed(to_integer(signed(r_triangle_even))+100, o_data_even'length));
      o_data_odd  <= std_logic_vector(to_signed(to_integer(signed(r_triangle_odd ))+100, o_data_odd'length ));

      if r_count = 14 then
        r_count <= 0;
        if to_integer(unsigned(r_random_select)) > c_PEAK_THRES then
          if r_random_height(14) = '0' then
            o_data_odd  <= r_random_height(g_ADC_BITS-1 downto 0);
          else
            o_data_even <= r_random_height(g_ADC_BITS-1 downto 0);
          end if;
        end if;
      else
        r_count <= r_count + 1;
      end if;
    end if;
  end process;
end behave;








-- Pseudo random source
library ieee;
use ieee.std_logic_1164.all;

entity lfsr is
  generic (
    SEED: std_logic_vector(14 downto 0)
    );
  port (
    clk : in std_logic;
    count : out std_logic_vector (14 downto 0)
    );
end entity;

architecture rtl of lfsr is
  signal count_i : std_logic_vector (14 downto 0) := SEED;
  signal feedback : std_logic;

begin
  feedback <= not(count_i(14) xor count_i(13));
  process (clk)
  begin
    if (rising_edge(clk)) then
      count_i <= count_i(13 downto 0) & feedback;
    end if;
  end process;
  count <= count_i;
end architecture;
