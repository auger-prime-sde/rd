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
  signal datavalid : std_logic := '0';
  signal out_1 : std_logic := '0';
  signal out_2 : std_logic := '0';
  signal data : std_logic_vector(c_DATASIZE-1 downto 0);
  
  component data_writer is
    generic (
      g_WORDSIZE : natural := 12 );
    port (
      -- inputs
      i_data      : in std_logic_vector(2*g_WORDSIZE-1 downto 0);
      i_dataready : in std_logic;
      i_clk       : in std_logic;
      -- outputs
      o_data_1    : out std_logic := '1';
      o_data_2    : out std_logic := '1';
      o_valid     : out std_logic := '1';
      o_clk       : out std_logic);
  end component;

  
begin
  -- DUT instantiation
  dut : data_writer
    port map (
      i_data       => data,
      i_dataready  => tx_enable,
      i_clk        => clk,
      o_data_1     => out_1,
      o_data_2     => out_2,
      o_valid      => datavalid,
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

  p_test : process is
  begin
    data(11 downto 0) <= std_logic_vector(to_unsigned(42, 12));
    data(23 downto 12) <= "111100111110";
    wait for 70 ns; -- arbitrary rising edge
    assert out_1 = '1' and out_2 = '1' report "data lines not high when not in use";
    assert datavalid = '0' report "valid data reported when no data was actually transmitted";

    tx_enable <= '1';
    wait for clk_period;
    wait for clk_period /2;
    for i in 0 to 11 loop
      assert datavalid = '1' report "valid pin not high";
      assert out_1 = data(11-i) report "data mismatch";
      assert out_2 = data(23-i) report "data mismatch";
      wait for clk_period/2;
      if i=11 then
        tx_enable <= '0';
      end if;
       
      wait for clk_period/2;
      
    end loop;
    assert datavalid = '1' report "no parity bit received";
    assert out_1 = '0' report "wrong parity bit for channel 1";
    assert out_2 = '0' report "wrong parity bit for channel 2";

    wait for clk_period/2;
    

    wait for clk_period/2; -- to get the new values
    assert datavalid = '0' report "incorrect datavalid reported";
    assert out_1 = '1' report "data not high outside transmission";
    assert out_2 = '1' report "data not high outside transmission";
        
    wait for 100 ns;
    
    stop <= '1';
    wait;

  end process;

end behavior;
