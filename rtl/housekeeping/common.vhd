library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;

package common is
  function num_bits(n:natural) return natural;
  
  type t_i2c_word is record
    data    : std_logic_vector(7 downto 0);
    addr    : std_logic_vector(2 downto 0);
    dir     : std_logic;
    ack     : std_logic;
    restart : std_logic;
  end record t_i2c_word;
  
  type t_i2c_data is array(natural range <>) of t_i2c_word;
  
end package common;

package body common is
  function num_bits(n:natural) return natural is
  begin
    if n > 0 then
      return 1+num_bits(n/2);
    else
      return 1;
    end if;
  end num_bits;
end package body common;
