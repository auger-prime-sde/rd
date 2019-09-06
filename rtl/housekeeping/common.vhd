library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;

package common is
  function num_bits(n:natural) return natural;
  
  --constant c_I2C_MAXBYTES : natural := 3;
  --constant c_I2C_MAXBYTES_BITS : natural := num_bits(c_I2C_MAXBYTES);
  --constant c_I2C_MAXBITS  : natural := 8*c_I2C_MAXBYTES; 

  type t_i2c_word is record
    data    : std_logic_vector(7 downto 0);
    addr    : std_logic_vector(2 downto 0);
    rw      : std_logic;
    restart : std_logic;
  end record t_i2c_word;
  
  type t_i2c_data is array(natural range <>) of t_i2c_word;
  --type t_i2c_data is array(integer range <>, integer range <>) of std_logic_vector(7 downto 0);
  
  
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
