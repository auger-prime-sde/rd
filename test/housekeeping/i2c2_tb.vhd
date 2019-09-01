library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity i2c2_tb is 
end i2c2_tb;

architecture behavior of i2c2_tb is

  constant clk_period : time := 20 ns;
  signal clk, stop : std_logic := '0';

  signal i_data : t_i2c_word;
  signal i_valid : std_logic;
  signal o_data : std_logic_vector(7 downto 0);
  signal o_next : std_logic;
  
  signal sda : std_logic;
  signal scl : std_logic;
  
  component i2c2 is
    generic (
      g_ADDR          : std_logic_vector(6 downto 0)
      );
    port(	--inputs
      i_clk      : in std_logic;
      i_data     : in t_i2c_word;
      i_valid    : in std_logic;
    
      --outputs
      o_data  : out std_logic_vector (7 downto 0); 
      o_next  : out std_logic;
    
      -- i2c interface
      sda	  : inout std_logic := 'Z';
      scl	  : inout std_logic := 'Z'
      );
  end component;

begin
  --DUT instantiation
  dut : i2c2
    generic map (
      g_ADDR          => "1001000"
      )
    port map(
      i_clk		    => clk,
      i_data        => i_data,
      i_valid	    => i_valid,
      o_data        => o_data,
      o_next        => o_next,
      sda			=> sda,
      scl			=> scl
      );
  
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

    -- single byte write
    wait for 142 ns;
    i_data.data <= "01011010";
    i_data.restart <= '1';
    i_data.rw <= '0';
    i_valid <= '1';
    wait for 10 * clk_period;
    i_valid <= '0';
    wait until o_next = '1';
    wait for 50 * clk_period;

    -- single byte read
    i_data.data <= (others => 'X');
    i_data.restart <= '1';
    i_data.rw <= '1';
    i_valid <= '1';
    wait for 10 * clk_period;
    i_valid <= '0';
    wait until o_next = '1';
    wait for 50 * clk_period;

    -- multi byte write
    i_data.data <= "01011010";
    i_data.restart <= '0';
    i_data.rw <= '0';
    i_valid <= '1';
    wait for 10 * clk_period;
    i_data.data <= "10100101";
    i_data.restart <= '0';
    wait for 30 * clk_period;
    i_valid <= '0';
    wait until o_next = '1';
    wait for 50 * clk_period;


    -- multi byte read
    i_data.data <= (others => 'X');
    i_data.restart <= '0';
    i_data.rw <= '1';
    i_valid <= '1';
    wait for 40 * clk_period;
    i_valid <= '0';
    wait until o_next = '1';
    wait for 50 * clk_period;


    -- repeated start between transactions
    i_data.data <= "11110000";
    i_data.restart <= '0';
    i_data.rw <= '0';
    i_valid <= '1';
    wait for 10 * clk_period;
    -- prep next transaction: read
    i_data.data <= (others => 'X');
    i_data.rw <= '1';
    i_data.restart <= '1';
    wait for 30 * clk_period;
    i_valid <= '0';
    wait until o_next = '1';
    wait for 50 * clk_period;

    
    -- multi byte read

    -- repeated start test
    
    wait for 50 * clk_period;

    stop <= '1';
    wait;
  end process;
end behavior;

    
