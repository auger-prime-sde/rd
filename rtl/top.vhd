--- AUGER radio extension FPGA toplevel design

library ieee;
use ieee.std_logic_1164.all;

entity top is
  port (
    dataIn : in std_logic_vector (11 downto 0);
    dataOvIn : in std_logic;
    clk : in std_logic;
    rst : in std_logic;

    o_led : out std_logic);
end top;

architecture behaviour of top is
  signal adc_data : std_logic_vector(25 downto 0);
  signal clk_intern : std_logic;
  signal address : std_logic_vector(10 downto 0);
  signal debug_q : std_logic;

  component adc_driver
    port (
      clkin: in  std_logic; reset: in  std_logic; sclk: out  std_logic;
      datain: in  std_logic_vector(12 downto 0);
      q: out  std_logic_vector(25 downto 0)
    );
  end component;

  component data_buffer
    port (
      i_wclk : in std_logic;
      i_we : in std_logic;
      i_waddr : in std_logic_vector(10 downto 0);
      i_wdata : in std_logic_vector(25 downto 0);
      i_rclk : in std_logic;
      i_re: in std_logic;
      i_raddr : in std_logic_vector(10 downto 0);
      o_rdata : out std_logic_vector(25 downto 0)
    );
  end component;

  component simple_counter
    port (
      i_clk: in std_logic;
      o_q: out std_logic_vector(10 downto 0)
    );
  end component;
begin

adc_driver_1 : adc_driver
  port map (
    clkin => clk,
    reset => rst,
    sclk => clk_intern,
    datain(11 downto 0) => datain,
    datain(12) => dataOvIn,
    q(25 downto 0) => adc_data);

write_index_counter : simple_counter
  port map (
    i_clk => clk_intern,
    o_q(10 downto 0) => address);

data_buffer_1 : data_buffer
  port map (
    i_wclk => clk_intern,
    i_we => '1',
    i_waddr => address,
    i_rclk => clk_intern,
    i_re => '1',
    i_raddr => address,
    i_wdata => adc_data,
    o_rdata(25 downto 1) => open,
    o_rdata(0) => debug_q);

  o_led <= debug_q;
end;
