library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_boot is
  port (
    i_clk       : in  std_logic;
    i_adc_clk   : in  std_logic;
    i_adc_ce    : in  std_logic;
    o_adc_reset : out std_logic;
    o_adc_clk   : out std_logic;
    o_adc_ce    : out std_logic
    );
end adc_boot;

  
architecture behave of adc_boot is
  type t_State is (s_Initial, s_Reset, s_Done, s_None);
  signal r_State : t_State := s_Initial;

begin
  o_adc_ce  <= i_adc_ce  when r_State = s_Done else '1'; -- 1 means LVDS+DDR
  o_adc_clk <= i_adc_clk when r_State = s_Done else '0'; -- 0 means high speed
  
  process (i_clk) is
  begin
    if rising_edge(i_clk) then
      case r_State is
        when s_Initial =>
          -- reset high puts the device in reset mode
          -- and allows setting the initial config through the ce/clk pins
          -- which is latched as soon as reset goes low again
          o_adc_reset <= '1';
          r_State <= s_Reset;
        when s_Reset =>
          o_adc_reset <= '0';
          r_State <= s_Done;
        when s_Done =>
          o_adc_reset <= '0';
          r_State <= s_Done;
        when s_None =>
          o_adc_reset <= '0';
          r_State <= s_Done;
      end case;
    end if;
  end process;
end behave;

    
