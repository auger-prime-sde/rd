library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity write_controller_tb is
end write_controller_tb;

architecture behavior of write_controller_tb is
  constant address_width : natural := 5; -- 32 entries in test buffer
  constant start_offset : natural := 7; -- start at trigger address - 7
  constant clk_period : time := 10 ns;

  signal clk, stop, trigger, arm : std_logic := '0';
  signal write_en, trigger_done : std_logic;
  signal curr_addr : std_logic_vector (address_width-1 downto 0);
  signal start_addr : std_logic_vector (address_width-1 downto 0);


  component write_controller is
    generic (
      g_ADDRESS_BITS : natural;
      g_START_OFFSET : natural
    );
    port (
      -- inputs
      i_clk          : in std_logic;
      i_trigger      : in std_logic;
      i_curr_addr    : in std_logic_vector(g_ADDRESS_BITS-1 downto 0);
      i_arm          : in std_logic;
      -- outputs
      o_write_en     : out std_logic;
      o_start_addr   : out std_logic_vector(g_ADDRESS_BITS-1 downto 0);
      o_trigger_done : out std_logic
    );
  end component;

  component simple_counter is
    generic (g_SIZE : natural);
    port (
      i_clk   : in std_logic;
      o_count : out std_logic_vector(g_SIZE-1 downto 0)
    );
  end component;

begin
  dut : write_controller
    generic map (g_ADDRESS_BITS => address_width, g_START_OFFSET => start_offset)
    port map (
        i_clk => clk,
        i_trigger => trigger,
        i_curr_addr => curr_addr,
        i_arm => arm,
        o_write_en => write_en,
        o_start_addr => start_addr,
        o_trigger_done => trigger_done
      );

  write_counter : simple_counter
    generic map (g_SIZE => address_width)
    port map ( i_clk => clk, o_count => curr_addr );

  p_clk : process is
  begin
    if stop = '1' then
      wait;
    end if;
    wait for clk_period/2;
    clk <= not clk;
  end process;

  p_test : process is
  begin
    wait for 20 ns;

    -- Test ignore of trigger while in idle state
    trigger <= '1';
    wait for 20 ns;
    assert write_en = '0' report "Trigger accepted while in idle state?" severity error;
    trigger <= '0';
    wait for 20 ns;

    -- Check if arming works
    arm <= '1';
    wait for 20 ns;
    assert write_en = '1' report "Buffer not writing when armed" severity error;

    -- Stays armed when signal is removed?
    arm <= '0';
    wait for 90 ns;
    assert write_en = '1' report "Buffer not writing when armed" severity error;
    -- wait for enough data to accumulate
    wait for clk_period * 100;
    
    -- Generates start address when triggered
    trigger <= '1';
    wait for 15 ns;
    trigger <= '0';
    -- Currently starting the 18th clock cycle, check if offset was calculated correctly
    assert unsigned(start_addr) = 23-start_offset report "Wrong start address generated" severity error;

    -- Check trigger finish
    wait for 340 ns;
    assert write_en = '0' report "Buffer still writing when done" severity error;
    assert trigger_done = '1' report "Trigger done signal not asserted when finished" severity error;

    -- Check for correct wrap-around in start address calculation
    -- Arm
    arm <= '1';
    wait for 20 ns;
    arm <= '0';

    wait for 100 ns;
    -- Trigger
    trigger <= '1';
    wait for 10 ns;
    trigger <= '0';
    wait for 300 ns;
    -- Finish
    assert unsigned(start_addr) = 23-start_offset report "Wrong start address generated (wraparound)" severity error;

    wait for 10 ns;
    stop <= '1';
    wait;
  end process;

end behavior;
