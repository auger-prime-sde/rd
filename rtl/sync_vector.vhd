library ieee;
use ieee.std_logic_1164.all;


entity sync_vector is
  generic (
    g_WIDTH : natural
    );
  port (
    i_clk  : in  std_logic;
    i_data : in  std_logic_vector(g_WIDTH-1 downto 0);
    o_data : out std_logic_vector(g_WIDTH-1 downto 0)
    );
end sync_vector;

architecture behave of sync_vector is
  signal stage1, stage2 : std_logic_vector(g_WIDTH-1 downto 0);

  component sync_1bit is
    generic (
      g_NUM_STAGES : natural := 3
      );
    port (
      i_clk : in std_logic;
      i_data :in  std_logic;
      o_data : out std_logic
      );
  end component;
  
  
begin

  g_sync: for i in 0 to g_WIDTH - 1 generate
    s : sync_1bit
      port map (
        i_clk => i_clk,
        i_data => i_data(i),
        o_data => stage1(i)
        );
  end generate g_sync;

  
  p_sync : process (i_clk) is
  begin
    if rising_edge(i_clk) then
      if stage1 = stage2 then
        o_data <= stage2;
      end if;
      stage2 <= stage1;
    end if;
  end process;


end behave;
