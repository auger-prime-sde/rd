library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity readout_controller_tb is
end readout_controller_tb;

architecture behavior of readout_controller_tb is
  constant width: natural := 11;
  constant clk_period : time := 10 ns;

  signal stop : std_logic := '0';
  signal i_clk : std_logic;
  signal i_start_addr : std_logic_vector(width-1 downto 0);
  signal i_trigger_done : std_logic;
  signal i_tx_start : std_logic;
  
  signal o_arm : std_logic := '0';
  signal o_read_addr : std_logic_vector(width-1 downto 0);
  signal o_read_enable : std_logic;
  signal o_tx_enable : std_logic;

  component readout_controller is
    generic (g_ADDRESS_BITS : natural);
    port (
      i_clk          : in std_logic;
      i_trigger_done : in std_logic;
      i_start_addr   : in std_logic_vector(g_ADDRESS_BITS-1 downto 0);
      o_arm          : out std_logic := '0';
      o_read_enable  : out std_logic := '1';
      o_read_addr    : out std_logic_vector(g_ADDRESS_BITS-1 downto 0);
      o_tx_enable    : out std_logic := '0';
      i_tx_start     : in std_logic
    );
  end component;

begin
  -- DUT instantiation
  dut : readout_controller
    generic map (g_ADDRESS_BITS => width)
    port map (
      i_clk => i_clk,
      i_trigger_done => i_trigger_done,
      i_start_addr => i_start_addr,
      o_arm => o_arm,
      o_read_enable => o_read_enable,
      o_read_addr => o_read_addr,
      o_tx_enable => o_tx_enable,
      i_tx_start => i_tx_start
    );

  p_clk : process is
  begin
    -- Finish simulation when stop is asserted
    if stop = '1' then
      wait;
    end if;


    wait for clk_period / 2;
    i_clk <= '0';
    wait for clk_period / 2;
    i_clk <= '1';
  end process;

  p_test : process is
  begin
    -- prepare
    -- let's assume the write controller is done and  we are waiting for a readout
    -- the start address has some arbitrary value
    -- the serial is ready for the next word
    i_tx_start <= '0'; 
    i_trigger_done <= '1';
    i_start_addr <= std_logic_vector(to_unsigned(42, width));
    
    
    wait for 1051 ns;

    i_tx_start <= '1';
    wait for 100*clk_period;
    i_tx_start <= '0';
            

    wait for 13*2048*clk_period - 100 * clk_period;
        
    --wait for 3 * clk_period;
    i_trigger_done <= '0';
    

    wait for 100 us;
    
    stop <= '1';
    wait;
  end process;

end behavior;
