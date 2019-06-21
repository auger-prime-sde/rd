library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity readout_controller is
  generic (
    g_ADDRESS_BITS : natural := 11;
    g_WORDSIZE : natural := 12
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
    -- interface to transmit
    o_tx_enable    : out std_logic := '0';
    -- interface to host
    i_tx_start     : in std_logic
    );
end readout_controller;


architecture behave of readout_controller is
  constant c_TRANSMIT_BITS :natural := g_WORDSIZE + 1; -- one parity bit
  -- state machine type:
  type t_State is (s_Initial, s_Idle, s_Busy, s_ExtraClk, s_Arm);
  -- variables:
  signal r_State : t_State := s_Initial;
  signal r_read_addr : std_logic_vector(g_ADDRESS_BITS-1 downto 0);
  signal r_Count : natural  range 0 to c_TRANSMIT_BITS-1 := 0;
  signal r_trigger_done : std_logic := '0';
  signal r_tx_start : std_logic := '0';
  
  
begin
--  main program
  p_transmit : process (i_clk) is
  begin
    if rising_edge(i_clk) then
      r_trigger_done <= i_trigger_done;
      r_tx_start <= i_tx_start;
      case r_State is
        when s_Initial =>
          o_arm <= '1';
          r_State <= s_Idle;
        when s_Idle =>
          o_tx_enable <= '0';
          o_arm <= '0';
          r_read_addr <= i_start_addr;
          if r_trigger_done='1' and r_tx_start='1' then
            r_State <= s_Busy;
            r_Count <= 0;
            o_tx_enable <= '1';
          end if;
        when s_Busy =>
          r_Count <= (r_Count + 1) mod c_TRANSMIT_BITS;
          if r_Count = c_TRANSMIT_BITS-2 then
            r_read_addr <= std_logic_vector((unsigned(r_read_addr)+1) mod 2**g_ADDRESS_BITS);
		  end if;
		  if r_Count = c_TRANSMIT_BITS-1 then
            if r_read_addr = std_logic_vector(unsigned(i_start_addr)) then
              r_State <= s_ExtraClk;
              o_tx_enable <= '1';
              r_Count <= 0;
            else
              o_tx_enable <= '1';
            end if;
          end if;
        when s_ExtraClk =>
          r_count <= (r_count + 1) mod c_TRANSMIT_BITS;
          if r_count = c_TRANSMIT_BITS-3 then
            o_tx_enable <= '0';
            o_arm <= '1';
            r_state <= s_Arm;
          end if;
        when s_Arm =>
          if r_trigger_done = '0' then
            r_State <= s_Idle;
          end if;
      end case;
    end if;
  end process;

  o_read_enable <= '1';
  o_read_addr <= r_read_addr;


end behave;

