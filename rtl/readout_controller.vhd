library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity readout_controller is
  generic (
    g_ADDRESS_BITS : natural := 11;
    g_WORDSIZE : natural := 13
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
    o_tx_enable    : out std_logic := '0';
    -- interface to host
    i_tx_start     : in std_logic
    );
end readout_controller;


architecture behave of readout_controller is
  -- state machine type:
  type t_State is (s_Initial, s_Idle, s_Busy, s_Arm);
  -- variables:
  signal r_State : t_State := s_Initial;
  signal r_read_addr : std_logic_vector(g_ADDRESS_BITS-1 downto 0);
  signal r_Count : natural  range 0 to g_WORDSIZE-1 := 0;

  
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
            r_State <= s_Busy;
            r_Count <= 0;
            o_tx_enable <= '1';
          end if;
        when s_Busy =>
          r_Count <= (r_Count + 1) mod g_WORDSIZE;
          if r_Count = g_WORDSIZE-2 then
            r_read_addr <= std_logic_vector((unsigned(r_read_addr)+1) mod 2**g_ADDRESS_BITS);
		  end if;
		  if r_Count = g_WORDSIZE-1 then
            if r_read_addr = std_logic_vector(unsigned(i_start_addr)) then
              o_tx_enable <= '0';
              o_arm <= '1';
              r_State <= s_Arm;
            else
              o_tx_enable <= '1';
            end if;
          end if;
        when s_Arm =>
          if i_trigger_done = '0' then
            r_State <= s_Idle;
          end if;
      end case;
    end if;
  end process;

  o_read_enable <= '1';
  o_read_addr <= r_read_addr;


end behave;

