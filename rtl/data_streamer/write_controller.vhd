library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity write_controller is
  generic (
    g_ADDRESS_BITS : natural := 11;
    g_TRACE_LENGTH : natural := 2048 -- 2**11
  );
  port (
    -- inputs
    i_rst          : in std_logic;
    i_clk          : in std_logic;
    i_trigger      : in std_logic;
    i_curr_addr    : in std_logic_vector(g_ADDRESS_BITS-1 downto 0);
    i_arm          : in std_logic;
    i_start_offset : in std_logic_vector(g_ADDRESS_BITS-1 downto 0);
    -- outputs
    o_write_en     : out std_logic := '0';
    o_start_addr   : out std_logic_vector(g_ADDRESS_BITS-1 downto 0) := (others => '0');
    o_trigger_done : out std_logic := '0'
  );
end write_controller;

architecture behavior of write_controller is
  -- Number of bytes to read before trigger: block size minus start offset
  --signal r_delay_count : natural range 0 to 2**g_ADDRESS_BITS-1;
  -- state machine type:
  type t_controller_state is (s_Idle, s_Armed, s_ArmReady, s_Triggered);
  -- In idle: no data is written to the buffer. This waits for an arm event
  -- that is sent by the readout controller when readout is finished and it is
  -- safe again to start writing to the buffer.
  -- In Armed: data is written to the buffer but the system is not yet
  -- sensitive to triggers because the minimum pre-trigger length is not yet
  -- written to the buffer.
  -- In ArmReady: data is being written to the buffer and the system is ready
  -- to receive a trigger.
  -- In Triggered: the system is writing the post-trigger samples to the
  -- buffer. When this is done the state will change back to Idle until the
  -- data is read out.
  -- variables
  signal r_controller_state : t_controller_state := s_Armed;
  signal r_start_addr, r_end_addr : natural range 0 to 2**g_ADDRESS_BITS-1 := 0;
  signal r_count : natural range 0 to 2**g_ADDRESS_BITS-1 := 0;
  --signal test_count : std_logic_vector(11 downto 0) := (others => '0');
  signal r_arm : std_logic := '0';
  signal r_trigger_done : std_logic := '0';
  --signal r_trigger : std_logic := '0';
  signal test_state : integer;
  
begin

  test_state <= 0 when r_controller_state = s_Idle else
                1 when r_controller_state = s_Armed else
                2 when r_controller_state = s_ArmReady else
                3 when r_controller_state = s_Triggered else
                -1;
  --r_delay_count <= g_TRACE_LENGTH - to_integer(unsigned(i_start_offset));

  o_trigger_done <= r_trigger_done;
  o_write_en <= not r_trigger_done;
        
  p_main : process (i_rst, i_clk) is
  begin
    
    if i_rst = '1' then
      r_arm <= '0';
      r_controller_state <= s_Armed;
      r_count <= 0;
      r_start_addr <= 0;
      --o_trigger_done <= '0';
      --o_write_en <= '0'; 
    else
      
      if rising_edge(i_clk) then
        --r_trigger <= i_trigger;
        r_arm <= i_arm;
        case r_controller_state is
          when s_Idle =>
            -- Wait for ARM event, signal done to read controller and keep write enable low until armed
            r_start_addr <= r_start_addr;
            r_count <= 0;

            if r_arm = '1' then
              r_Controller_State <= s_Armed;
              r_trigger_done <= '0';
            else
              r_controller_state <= s_Idle;
            end if;
          when s_Armed =>
            -- wait for at least half the buffer to be filled
            r_start_addr <= r_start_addr;
            r_count <= (r_count + 2);-- mod (r_delay_count + 1);

            if r_count < to_integer(unsigned(i_start_offset)) then
              r_controller_state <= s_Armed;
            else
              r_controller_state <= s_ArmReady;
            end if;
          when s_ArmReady =>
            -- Wait for TRIGGER event
            --  once trigger arrives calculate new start address for read controller
            --  and start counting remaining values read (in s_Triggered)
            r_count <= 0;

            if i_trigger = '1' then
              r_start_addr <= (to_integer(unsigned(i_curr_addr)) - to_integer(unsigned(i_start_offset)) ) mod 2**o_start_addr'length;
              r_end_addr <= (to_integer(unsigned(i_curr_addr)) - to_integer(unsigned(i_start_offset)) + g_TRACE_LENGTH -1) mod 2**o_start_addr'length;
              r_controller_state <= s_Triggered;
            else
              r_start_addr <= r_start_addr;
              r_controller_state <= s_ArmReady;
            end if;

          when s_Triggered =>
            -- Read remaining values from input
            --    send signal to the read controller,
            --    and go to idle
            r_start_addr <= r_start_addr;
            r_count <= (r_count + 2) ;

            --if r_count < r_delay_count - 5 then
            if unsigned(i_curr_addr(g_ADDRESS_BITS-1 downto 1)) = to_unsigned(r_end_addr, o_start_addr'length)(g_ADDRESS_BITS-1 downto 1) then
              -- The minus 6 compensates for the fact that:
              -- r_count starts counting after the trigger
              -- o_write_enable should be asserted low before the last sample
              -- there is a delay between going to idle and asserting
              -- write_enbale low
              r_controller_state <= s_Idle;
              r_trigger_done <= '1';
            else 
              r_controller_state <= s_Triggered;             
            end if;
        end case;
        
      end if;  -- if rising_edge(i_clk)
    end if;
  end process;


  --test_count <= std_logic_vector(to_unsigned(r_Count,12));
  o_start_addr <= std_logic_vector(to_unsigned(r_start_addr, o_start_addr'length));
end behavior;
