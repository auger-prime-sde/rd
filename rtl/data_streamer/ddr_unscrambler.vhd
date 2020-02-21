library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ddr_unscrambler is
  port (
    i_data : in std_logic_vector(51 downto 0);
    o_data_ns_even : out std_logic_vector(11 downto 0);
    o_data_ns_odd  : out std_logic_vector(11 downto 0);
    o_data_ew_even : out std_logic_vector(11 downto 0);
    o_data_ew_odd  : out std_logic_vector(11 downto 0);
    o_trigger      : out std_logic_vector(0 to 3)
    );
end ddr_unscrambler;

architecture behave of ddr_unscrambler is
  constant c_ADC_BITS : natural := 12;
begin
  o_trigger(3)      <= i_data(4*(c_ADC_BITS+1)-1);
  o_trigger(2)      <= i_data(3*(c_ADC_BITS+1)-1);
  o_trigger(1)      <= i_data(2*(c_ADC_BITS+1)-1);
  o_trigger(0)      <= i_data(1*(c_ADC_BITS+1)-1);

  o_data_ns_even(11) <= i_data(18);
  o_data_ns_even(10) <= i_data(5);
  o_data_ns_even( 9) <= i_data(17);
  o_data_ns_even( 8) <= i_data(4);
  o_data_ns_even( 7) <= i_data(16);
  o_data_ns_even( 6) <= i_data(3);
  o_data_ns_even( 5) <= i_data(15);
  o_data_ns_even( 4) <= i_data(2);
  o_data_ns_even( 3) <= i_data(14);
  o_data_ns_even( 2) <= i_data(1);
  o_data_ns_even( 1) <= i_data(13);
  o_data_ns_even( 0) <= i_data(0);

  o_data_ns_odd(11) <= i_data(44);
  o_data_ns_odd(10) <= i_data(31);
  o_data_ns_odd( 9) <= i_data(43);
  o_data_ns_odd( 8) <= i_data(30);
  o_data_ns_odd( 7) <= i_data(42);
  o_data_ns_odd( 6) <= i_data(29);
  o_data_ns_odd( 5) <= i_data(41);
  o_data_ns_odd( 4) <= i_data(28);
  o_data_ns_odd( 3) <= i_data(40);
  o_data_ns_odd( 2) <= i_data(27);
  o_data_ns_odd( 1) <= i_data(39);
  o_data_ns_odd( 0) <= i_data(26);

  o_data_ew_even(11) <= i_data(24);
  o_data_ew_even(10) <= i_data(11);
  o_data_ew_even( 9) <= i_data(23);
  o_data_ew_even( 8) <= i_data(10);
  o_data_ew_even( 7) <= i_data(22);
  o_data_ew_even( 6) <= i_data( 9);
  o_data_ew_even( 5) <= i_data(21);
  o_data_ew_even( 4) <= i_data( 8);
  o_data_ew_even( 3) <= i_data(20);
  o_data_ew_even( 2) <= i_data( 7);
  o_data_ew_even( 1) <= i_data(19);
  o_data_ew_even( 0) <= i_data( 6);

  o_data_ew_odd(11) <= i_data(50);
  o_data_ew_odd(10) <= i_data(37);
  o_data_ew_odd( 9) <= i_data(49);
  o_data_ew_odd( 8) <= i_data(36);
  o_data_ew_odd( 7) <= i_data(48);
  o_data_ew_odd( 6) <= i_data(35);
  o_data_ew_odd( 5) <= i_data(47);
  o_data_ew_odd( 4) <= i_data(34);
  o_data_ew_odd( 3) <= i_data(46);
  o_data_ew_odd( 2) <= i_data(33);
  o_data_ew_odd( 1) <= i_data(45);
  o_data_ew_odd( 0) <= i_data(32);

end behave;

    
