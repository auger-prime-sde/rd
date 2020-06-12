library ieee;
use ieee.std_logic_1164.all;

entity stretch is
  generic (
    g_LENGTH : natural := 3
    );
  port (
    i_clk  : in std_logic;
    i_data : in std_logic;
    o_data : out std_logic
    );
end stretch;





architecture behave of stretch is
	function or_reduce( V: std_logic_vector )
                return std_ulogic is
      variable result: std_ulogic;
    begin
      for i in V'range loop
        if i = V'left then
          result := V(i);
        else
          result := result OR V(i);
        end if;
        exit when result = '1';
      end loop;
      return result;
    end or_reduce;


  signal fifo : std_logic_vector(g_LENGTH-1 downto 0) := (others => '0');
begin
  p_stretch : process (i_clk) is
  begin
    if rising_edge(i_clk) then
      fifo <= fifo(g_LENGTH-2 downto 0) & i_data;
    end if;
  end process;

  o_data <= or_reduce(fifo);
end behave;

    
    