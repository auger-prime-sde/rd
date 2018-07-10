library ieee;
use ieee.std_logic_1164.all;

entity data_buffer_tb is
end data_buffer_tb;

architecture behavior of data_buffer_tb is
	constant address_width : natural := 12;
	constant data_width : natural := 32;
	constant clk_period : time := 10 ns;

  signal i_wclk, i_we, i_rclk, i_re : std_logic := '0';
  signal i_wdata, o_rdata : std_logic_vector(data_width-1 downto 0) := (others => '0');
  signal i_waddr, i_raddr : std_logic_vector(address_width-1 downto 0) := (others => '0');
  signal stop : std_logic := '0';

	component data_buffer is
		generic (g_DATA_WIDTH, g_ADDRESS_WIDTH : natural);
		port (
      -- Write port
      i_wclk : in std_logic;
      i_we : in std_logic;
      i_waddr : in std_logic_vector(address_width-1 downto 0);
      i_wdata : in std_logic_vector(data_width-1 downto 0);
      -- Read port
      i_rclk : in std_logic;
      i_re: in std_logic;
	    i_raddr : in std_logic_vector(address_width-1 downto 0);
		  o_rdata : out std_logic_vector(data_width-1 downto 0)
    );
	end component;

begin
  -- DUT instantiation
  dut : data_buffer
    generic map (g_DATA_WIDTH => data_width, g_ADDRESS_WIDTH => address_width)
    port map (
      i_wclk => i_wclk,
      i_we => i_we,
      i_waddr => i_waddr,
      i_wdata => i_wdata,
      i_rclk => i_rclk,
      i_re => i_re,
      i_raddr => i_raddr,
      o_rdata => o_rdata);

  p_wclk : process is
  begin
    -- Finish simulation when stop is asserted
    if stop = '1' then
      wait;
    end if;

    i_wclk <= not(i_wclk);
    wait for clk_period / 2;
  end process;

  i_rclk <= not(i_wclk);

  p_test : process is
  begin
    wait for 20 ns;

    i_we    <= '1';
    wait for 10 ns;
    i_we    <= '0';
    assert o_rdata = x"00000000" report "Value loading problem" severity error;


    i_waddr <= x"001";
    i_wdata <= x"00000101";
    wait for 10 ns;

    i_we    <= '1';
    wait for 10 ns;
    i_we    <= '0';
    assert o_rdata = x"00000000" report "Value overwritten" severity error;

    i_raddr <= x"000";
    wait for 30 ns;

    i_re    <= '1';
    wait for 10 ns;
    i_re    <= '0';

    i_raddr <= x"001";
    wait for 30 ns;
    assert o_rdata = x"00000000" report "Value early loading problem" severity error;

    i_re    <= '1';
    wait for 10 ns;
    i_re    <= '0';
    assert o_rdata = x"00000101" report "Value loading problem" severity error;

    wait for 30 ns;
    stop <= '1';
    wait;
  end process;

end behavior;
