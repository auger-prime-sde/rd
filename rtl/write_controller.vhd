library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity write_controller is
  generic (
    g_ADDRESS_BITS : natural := 11;
    g_START_OFFSET : integer := -1024
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
end write_controller;

architecture behavior of write_controller is
  -- Number of bytes to read, block size - 1, minus start offset
  constant c_delay_count : natural := 2**(g_ADDRESS_BITS) + g_START_OFFSET - 1;
  -- state machine type:
  type t_controller_state is (s_Idle, s_Armed, s_Triggered);
  -- variables
  signal r_controller_state : t_controller_state := s_Idle;
  signal r_start_addr : std_logic_vector(g_ADDRESS_BITS-1 downto 0) := (others => '0');
  signal r_count : natural range 0 to c_delay_count-1 := 0;
begin
  p_main : process (i_clk) is
  begin
    if rising_edge(i_clk) then
      case r_Controller_State is
        when s_Idle =>
          -- Wait for ARM event, signal done to read controller and keep write enable low until armed
          o_trigger_done <= '1';
          if i_arm = '1' then
            r_Controller_State <= s_Armed;
            r_start_addr <= r_start_addr;
            o_write_en <= '1';
          else
            o_write_en <= '0';
          end if;

        when s_Armed =>
          -- Wait for TRIGGER event
          --  once trigger arrives calculate new start address for read controller
          --  and start counting remaining values read (in s_Triggered)
          o_trigger_done <= '0';
          o_write_en <= '1';
          if i_trigger = '1' then
            r_start_addr <= std_logic_vector(signed(i_curr_addr) + g_START_OFFSET + 1);
            r_controller_state <= s_Triggered;
            r_count <= 0;
          end if;

        when s_Triggered =>
          -- Read remaining values from input
          --  when done:
          --    stop the write enable,
          --    send signal to the read controller,
          --    and go to idle
          if r_count < c_delay_count-1 then
            o_trigger_done <= '0';
            o_write_en <= '1';
            r_count <= r_count + 1;
            r_controller_state <= s_Triggered;
          else
            o_trigger_done <= '1';
            o_write_en <= '0';
            r_count <= 0;
            r_controller_state <= s_Idle;
          end if;
      end case;
    end if;  -- if rising_edge(i_clk)
  end process;

  o_start_addr <= r_start_addr;
end behavior;
