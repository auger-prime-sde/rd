library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_boot is
  port (
    i_hk_fast_clk  : in  std_logic;
    i_hk_adc_clk   : in  std_logic;
    i_hk_adc_ce    : in  std_logic;
    i_hk_adc_mosi  : in  std_logic;
    o_hk_adc_reset : out std_logic;
    o_hk_adc_clk   : out std_logic;
    o_hk_adc_ce    : out std_logic;
    o_hk_adc_mosi  : out std_logic
    );
end adc_boot;

  
architecture behave of adc_boot is

  constant c_RESET_CYCLES : natural := 3; -- how long to pull the reset line
                                          -- low in terms of 50MHz input clock
                                          -- cylces. 

  signal r_Count : natural range 0 to 2 * c_RESET_CYCLES := 2 * c_RESET_CYCLES;
  
begin
      
  process (i_hk_fast_clk) is
  begin

    if r_Count > c_RESET_CYCLES then
      -- during the reset force the following line values:
      o_hk_adc_ce    <= '1'; -- reboot in LVDS+DDR mode
      o_hk_adc_clk   <= '0'; -- reboot in fast mode
      o_hk_adc_mosi  <= '0'; -- value is ignored
      o_hk_adc_reset <= '1'; -- adc reset active high
    elsif r_Count > 0 then
      -- let the device boot up with these lines
      o_hk_adc_ce    <= '1'; -- reboot in LVDS+DDR mode
      o_hk_adc_clk   <= '0'; -- reboot in fast mode
      o_hk_adc_mosi  <= '0'; -- value is ignored
      o_hk_adc_reset <= '0'; -- adc reset active high
    elsif i_hk_adc_ce = '0' then
      -- after boot, forward spi but keep lines quiet when not addressing the adc
      o_hk_adc_ce    <= i_hk_adc_ce;
      o_hk_adc_clk   <= i_hk_adc_clk;
      o_hk_adc_mosi  <= i_hk_adc_mosi;
      o_hk_adc_reset <= '0';
    else
      -- else: keep lines quiet
      o_hk_adc_ce    <= '1';
      o_hk_adc_clk   <= '1';
      o_hk_adc_mosi  <= '0';
      o_hk_adc_reset <= '0';
    end if;
    


    
    if rising_edge(i_hk_fast_clk) then
      if r_Count /= 0 then
        r_Count <= r_Count - 1;
      end if;
    end if;
  end process;
end behave;

    
