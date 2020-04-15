library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity write_controller_tb is
end write_controller_tb;

architecture behavior of write_controller_tb is
  constant address_width : natural := 5; -- 32 entries in test buffer
  constant start_offset  : natural := 10; -- start at trigger address - 7
  constant clk_period    : time := 10 ns;

  signal clk, rst, stop, trigger, arm : std_logic := '0';
  signal write_en, trigger_done : std_logic;
  signal curr_addr : std_logic_vector (address_width-1 downto 0);
  signal start_addr : std_logic_vector (address_width-1 downto 0);


  component write_controller is
    generic (
      g_ADDRESS_BITS : natural
    );
    port (
      -- inputs
      i_clk          : in std_logic;
      i_rst          : in std_logic;
      i_trigger      : in std_logic;
      i_curr_addr    : in std_logic_vector(g_ADDRESS_BITS-1 downto 0);
      i_arm          : in std_logic;
      i_start_offset : in std_logic_vector(g_ADDRESS_BITS-1 downto 0);
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
    generic map (g_ADDRESS_BITS => address_width)
    port map (
        i_clk => clk,
        i_rst => rst,
        i_trigger => trigger,
        i_curr_addr => curr_addr,
        i_arm => arm,
        i_start_offset => std_logic_vector(to_unsigned(start_offset, address_width)),
        o_write_en => write_en,
        o_start_addr => start_addr,
        o_trigger_done => trigger_done
      );

  curr_addr(0) <= '0';
  write_counter : simple_counter
    generic map (g_SIZE => address_width-1)
    port map ( i_clk => clk, o_count => curr_addr(address_width-1 downto 1) );

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
    rst <= '1';
    wait for 10 ns;
    rst <= '0';
    wait for 20 ns;

    -- Controller starts in armed condition
    assert write_en = '1' report "Not armed on start?" severity error;

    -- Test ignore of trigger while processing pre-trigger data
    trigger <= '1';
    wait for 20 ns;
    trigger <= '0';
    wait for (2**address_width)* clk_period;
    assert write_en = '1' report "Trigger accepted while processing pre-trigger data?" severity error;
    wait for 20 ns;

    -- Stays armed when signal is removed?
    arm <= '0';
    wait for 100 ns;
    assert write_en = '1' report "Buffer not writing when armed" severity error;
    -- wait for enough data to accumulate
    wait for clk_period * 80;

    -- Generates start address when triggered
    trigger <= '1';
    wait for 10 ns;
    trigger <= '0';
    -- Check if offset was calculated correctly
    -- First trigger uses i_start_offset = 0
    assert unsigned(start_addr) = (unsigned(curr_addr)+2*start_offset) mod 2**address_width report "Wrong start address generated" severity error;

    -- Check trigger finish
    wait for 320 ns;
    assert write_en = '0' report "Buffer still writing when done" severity error;
    assert trigger_done = '1' report "Trigger done signal not asserted when finished" severity error;

    -- Check if arming works
    arm <= '1';
    wait for 30 ns;
    assert write_en = '1' report "Buffer not writing when armed" severity error;

    -- Check for correct wrap-around in start address calculation
    -- Arm
    arm <= '1';
    wait for 30 ns;
    arm <= '0';

    wait for 100 ns;
    -- Trigger
    trigger <= '1';
    wait for 10 ns;
    assert unsigned(start_addr) = (unsigned(curr_addr) + 2*start_offset) mod 2**address_width report "Wrong start address generated (wraparound)" severity error;
    wait for 20 ns;
    trigger <= '0';
    wait for 300 ns;
    -- Finish

    wait for 10 ns;
    stop <= '1';
    wait;
  end process;

  -- Properties that should hold throughout the simulation
  -- Requires VHDL-2008 support enabled
  properties : block is
  begin
    -- Set up default clock
    default clock is rising_edge(clk);

    -- 1: Check that trigger_done and write_en are never both active
    p_1_trigger_done_and_write:
      assert never trigger_done and write_en
      report "Still writing to memory while the trigger is done already?";

    -- 2: An accepted trigger eventually completes
    -- How to distinguish accepted and ignored triggers?
    p_2_trigger_completes:
      assert always trigger |=> eventually! trigger_done
      report "Partial trigger observed, test terminated early?";

    -- 3: There should be a succesful arm happening in the test
    p_3_test_full_sequence:
      cover {arm; trigger_done};

    -- 4: The trigger done goes up exactly one cycle after the rising edge of arm was observed
    p_4_trigger_done_delay:
      assert always
             {not arm; arm and trigger_done}
         |=> {(not write_en)[*1]; write_en}
      report "Incorrect time delay between trigger arm and starting to write?";

    -- TODO: finish writing property set

  end block properties;
end behavior;
