library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity readout_controller is
  generic (
    g_ADDRESS_BITS : natural := 11
    );
  port (
    i_clk       : in std_logic;
    -- interface to write controller:
    i_trigger_done : in std_logic;
    i_start_addr   : in std_logic_vector(g_ADDRESS_BITS-1 downto 0);
    o_arm          : out std_logic := '1';
    -- interface to data buffer:
    o_read_enable  : out std_logic := '1';
    o_read_addr    : out std_logic_vector(g_ADDRESS_BITS-1 downto 0);
    -- interface to uart
    i_word_ready   : in std_logic;
    o_tx_enable    : out std_logic := '0';
    -- interface to host
    o_tx_ready     : out std_logic := '1';
    i_tx_start     : in std_logic
    );
end readout_controller;


architecture behave of readout_controller is
  -- state machine type:
  type t_State is (s_Initial, s_Idle, s_Loaded, s_Busy);
  -- initial is only for the first clockcycle to force an arm signal to the
  -- write controller.
  -- loaded and busy are both states in which the machine is transmitting.
  -- busy indicates that the previous word is in transmission.
  -- loaded means that the next word has already been loaded and we are waiting
  -- for the uart to start transmitting that word.
  -- variables:
  signal r_State : t_State := s_Initial;
  signal r_read_addr : std_logic_vector(g_ADDRESS_BITS-1 downto 0);

  signal is_idle : std_logic;
  signal is_loaded : std_logic;
  signal is_busy : std_logic;
  
begin
--  main program
  p_transmit : process (i_clk) is
  begin
    if rising_edge(i_clk) then
      case r_State is
        when s_Initial =>
          o_arm <= '1';
          r_State <= s_Idle;
        when s_Idle =>
          o_tx_enable <= '0';
          o_arm <= '0';
          r_read_addr <= i_start_addr;
          if i_trigger_done='1' and i_tx_start='1' then
            r_State <= s_Loaded;
          else
            r_State <= s_Idle;
          end if;
        when s_Loaded =>
          o_arm <= '0';
          o_tx_enable <= '1';
          if i_word_ready = '0' then
            r_State <= s_Busy;
          end if;
        when s_Busy =>
          if r_read_addr = std_logic_vector(unsigned(i_start_addr)-1) then
            o_tx_enable <= '0';
          --else
          --  o_tx_enable <= '0';
          end if;
          if i_word_ready = '1' then
            --o_tx_enable <= '0';
            r_read_addr <= std_logic_vector((unsigned(r_read_addr)+1) mod 2**g_ADDRESS_BITS);
            if std_logic_vector((unsigned(r_read_addr)+1) mod 2**g_ADDRESS_BITS) = i_start_addr then
              r_State <= s_Idle;
              o_arm <= '1';
            else
              r_State <= s_Loaded;
              o_arm <= '0';
            end if;
          else
            --o_tx_enable <= '1';
          end if;
      end case;
    end if;
  end process;

  o_tx_ready <= '1' when r_State=s_Idle else '0';
  o_read_enable <= '1';
  o_read_addr <= r_read_addr;

  is_busy <= '1' when r_State = s_Busy else '0';
  is_loaded <= '1' when r_State = s_Loaded else '0';
  is_idle <= '1' when r_State = s_Idle else '0';
end behave;

