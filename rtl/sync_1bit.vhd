library ieee;
use ieee.std_logic_1164.all;


entity sync_1bit is
  generic (
    g_NUM_STAGES : natural := 3
    );
  port (
    i_clk : in std_logic;
    i_data :in  std_logic;
    o_data : out std_logic
    );
end sync_1bit;

architecture behave of sync_1bit is
  signal regs : std_logic_vector(g_NUM_STAGES-1 downto 0) := (others => '0');

begin
  p_sync : process (i_clk) is
  begin
    if rising_edge(i_clk) then
      regs <= regs(g_NUM_STAGES-2 downto 0) & i_data;
    end if;
  end process;

  o_data <= regs(g_NUM_STAGES-1);
end behave;

  
