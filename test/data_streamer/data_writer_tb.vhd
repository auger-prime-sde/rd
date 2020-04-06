library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity data_writer_tb is
end data_writer_tb;

architecture behavior of data_writer_tb is
  constant c_DATASIZE : natural := 24;
  constant clk_period : time := 20 ns;
  
  signal clk, tx_clk, stop : std_logic := '0';
  signal tx_enable : std_logic := '0';
  signal out_1 : std_logic := '0';
  signal out_2 : std_logic := '0';
  signal data : std_logic_vector(c_DATASIZE-1 downto 0);
  signal clk_padding : std_logic := '0';

  signal count : natural;
  type t_state is (s_idle_before, s_prepad, s_data, s_postpad, s_idle_after);
  signal state : t_state := s_idle_before;
  
  component data_writer is
    generic (
      g_WORDSIZE : natural := 12;
      g_TARGET_PARITY : std_logic := '1');
    port (
      -- inputs
      i_data      : in std_logic_vector(2*g_WORDSIZE-1 downto 0);
      i_dataready : in std_logic;
      i_clk       : in std_logic;
      i_clk_padding : in std_logic;
      -- outputs
      o_data_1    : out std_logic := '1';
      o_data_2    : out std_logic := '1';
      o_clk       : out std_logic);
  end component;

  
begin
  -- DUT instantiation
  dut : data_writer
    generic map (g_TARGET_PARITY => '1')
    port map (
      i_data       => data,
      i_dataready  => tx_enable,
      i_clk        => clk,
      i_clk_padding => clk_padding,
      o_data_1     => out_1,
      o_data_2     => out_2,
      o_clk        => tx_clk );


  p_clk : process is
  begin
    -- Finish simulation when stop is asserted
    if stop = '1' then
      wait;
    end if;

    clk <= '0';
    wait for clk_period / 2;
    clk <= '1';
    wait for clk_period / 2;
  end process;


  p_input : process(clk) is
  begin
    --if stop = '0' then
      if rising_edge(clk) then
        case state is
          when s_idle_before =>
            if count = 10 then
              state <= s_prepad;
              clk_padding <= '1';
              data(11 downto 0) <= std_logic_vector(to_unsigned(42, 12));
              data(23 downto 12) <= "111100111010";
              count <= 0;
            else
              count <= count + 1;
            end if;
          when s_prepad =>
            count <= count + 1;
            if count = 1 then
              tx_enable <= '1';
            elsif count = 2 then
              count <= 0;
              clk_padding <= '0';
              state <= s_data;
            end if;
          when s_data =>
            count <= count + 1;
            if count = 11 then
              data(23 downto 12) <= std_logic_vector(to_unsigned(42, 12));
              data(11 downto 0) <= "111100111010";
            end if;
            if count = 24 then
              tx_enable <= '0';
              clk_padding <= '1';
            end if;
            if count = 25 then
              state <= s_postpad;
              count <= 0;
            end if;
          when s_postpad =>
            count <= count + 1;
            if count = 11 then
              count <= 0;
              state <= s_idle_after;
              clk_padding <= '0';
            end if;
          when s_idle_after =>
            count <= count + 1;
            if count = 10 then
              stop <= '1';
            end if;
        end case;
      end if;
    --end if;
  end process;
  
        
          
          
  
  p_test : process is
  begin
    -- discard 4 leading clock edges
    for i in 0 to 3 loop
      wait until rising_edge(tx_clk);
    end loop;

    for i in 0 to 11 loop
      wait until rising_edge(tx_clk);
      assert out_1 = data(11-i) report "data mismatch";
      assert out_2 = data(23-i) report "data mismatch";
    end loop;

    wait until rising_edge(tx_clk);
    assert out_1 = '0' report "parity mismatch";
    assert out_2 = '1' report "parity mismatch";
    
    
    wait;
  end process;
  
  
  
  --p_test : process is
--  begin
--    data(11 downto 0) <= std_logic_vector(to_unsigned(42, 12));
--    data(23 downto 12) <= "111100111010";
--    wait for 66 ns; -- arbitrary rising edge
--    assert out_1 = '1' and out_2 = '1' report "data lines not high when not in use";
--
--    clk_padding <= '1';
--    wait for clk_period*3;
--    tx_enable <= '1';
--    --wait for clk_period;
--    wait for clk_period /2;
--    for i in 0 to 11 loop
--      assert out_1 = data(11-i) report "data mismatch";
--      assert out_2 = data(23-i) report "data mismatch";
--      wait for clk_period/2;
--      clk_padding <= '0';
--      wait for clk_period/2;
--    end loop;
--    assert out_1 = '0' report "wrong parity bit for channel 1";
--    assert out_2 = '1' report "wrong parity bit for channel 2";
--    wait for clk_period;
--    
--    for i in 0 to 11 loop
--      assert out_1 = data(11-i) report "data mismatch";
--      assert out_2 = data(23-i) report "data mismatch";
--      wait for clk_period/2;
--      if i=11 then
--        tx_enable <= '0';
--      end if;
--      wait for clk_period/2;
--    end loop;
--    assert out_1 = '0' report "wrong parity bit for channel 1";
--    assert out_2 = '1' report "wrong parity bit for channel 2";
--
--    wait for clk_period/2;
--    
--
--    wait for clk_period/2; -- to get the new values
--    assert out_1 = '1' report "data not high outside transmission";
--    assert out_2 = '1' report "data not high outside transmission";
--        
--    wait for 100 ns;
--    
--    stop <= '1';
--    wait;
--
--  end process;
--
end behavior;
