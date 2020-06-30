library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity write_controller_formal is
  generic (
      g_ADDRESS_BITS : natural := 5;
      g_TRACE_LENGTH : natural := 16
    );
  port (
      i_clk          : in std_logic;
      i_rst          : in std_logic;
      i_trigger      : in std_logic;
      i_curr_addr    : in std_logic_vector(g_ADDRESS_BITS-1 downto 0);
      i_arm          : in std_logic;
      i_start_offset : in std_logic_vector(g_ADDRESS_BITS-1 downto 0);
      o_write_en     : out std_logic := '0';
      o_start_addr   : out std_logic_vector(g_ADDRESS_BITS-1 downto 0);
      o_trigger_done : out std_logic := '0'
    );
end write_controller_formal;

architecture proof of write_controller_formal is

component write_controller
  generic (
    g_ADDRESS_BITS : natural;
    g_TRACE_LENGTH : natural
    );
  port (
      i_clk          : in std_logic;
      i_rst          : in std_logic;
      i_trigger      : in std_logic;
      i_curr_addr    : in std_logic_vector(g_ADDRESS_BITS-1 downto 0);
      i_arm          : in std_logic;
      i_start_offset : in std_logic_vector(g_ADDRESS_BITS-1 downto 0);
      o_write_en     : out std_logic := '0';
      o_start_addr   : out std_logic_vector(g_ADDRESS_BITS-1 downto 0);
      o_trigger_done : out std_logic := '0'
    );
end component;

  signal w_write_en, w_trigger_done : std_logic;
  signal w_start_addr : std_logic_vector(g_ADDRESS_BITS-1 downto 0);
  signal f_armed, f_triggered : std_logic;
begin

  dut : write_controller
    generic map (
        g_ADDRESS_BITS => g_ADDRESS_BITS,
        g_TRACE_LENGTH => g_TRACE_LENGTH
      )
    port map (
        i_clk          => i_clk,
        i_rst          => i_rst,
        i_trigger      => i_trigger,
        i_curr_addr    => i_curr_addr,
        i_arm          => i_arm,
        i_start_offset => i_start_offset,
        o_write_en     => w_write_en,
        o_start_addr   => w_start_addr,
        o_trigger_done => w_trigger_done
    );

  o_write_en     <= w_write_en;
  o_start_addr   <= w_start_addr;
  o_trigger_done <= w_trigger_done;

  -- Helpers to track internal state
  p_armed_tracker : process (i_clk, i_rst)
  begin
    if i_rst = '1' then
      f_armed <= '1';
    else
      if w_trigger_done = '1' then
        f_armed <= '0';
      end if;
      if i_arm = '1' then
        f_armed <= '1';
      end if;
    end if;
  end process;

  p_trigger_tracker : process (i_clk, i_rst)
  begin
    if i_rst = '1' then
      f_triggered <= '0';
    else
      if i_arm = '1' then
        f_triggered <= '0';
      end if;
      if i_trigger = '1' then
        f_triggered <= '1';
      end if;
    end if;
  end process;


  formal : block is
  begin
    -- Set default clock and force proper system reset at start
    default clock is rising_edge(i_clk);
    restrict {i_rst; not i_rst[+]};

    -- Assume triggers only happen when the controller is not yet triggered
--    assume never (i_trigger and w_trigger_done);
    assume always {not w_write_en; w_write_en[*8]} |=> i_trigger;

    -- Assume i_arm only happens when the controller is done processing a trigger
    --  Note, this seems to need an extra cycle to get properly registered
    assume never (i_arm and w_write_en);
    restrict {true[+]; not w_trigger_done[+]; i_arm}[+];

    c_1_trigger_once: cover {i_arm; w_trigger_done};
    c_2_write_cycle:  cover {w_write_en[+]; not w_write_en[+]; w_write_en[+]};

    -- Make sure that we indeed do get armed at some point
    f_check_armed: assert always eventually! i_arm;

    -- 1: After a trigger (when ready) we eventually get a trigger done
    f_1_trigger_completes: assert
      always (i_trigger |=> eventually! w_trigger_done) abort i_rst;

    -- 2: Outputs o_write_en and o_trigger_done are each others oposite
    f_2_write_or_done: assert
      always o_write_en /= o_trigger_done;

    -- 3: Whenever the signal i_arm is high and the signal o_write_en is low, the
    --    signal o_write_en should be high exactly 2? cycles of i_clk later
    -- TODO the 2 cycles is differen from what Tim had in his docs.
    f_3_arming: assert
      always (
            {not i_arm; i_arm and w_trigger_done} -- check on rising edge
        |=> {(w_write_en = '0')[*1]; w_write_en}
      ) abort i_rst;

  end block formal;
end proof;
