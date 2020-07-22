-------------------------------------------------------------------------------
-- Title      : icpx
-- Project    : DP RAM based FFT processor
-------------------------------------------------------------------------------
-- File       : icpx_pkg.vhd
-- Author     : Wojciech Zabolotny  wzab01<at>gmail.com
-- Company    : 
-- License    : BSD
-- Created    : 2014-01-18
-- Platform   : 
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: This package defines the format used to store complex numbers
--              In this implementation we store numbers from range <-2.0, 2.0)
--              scaled to signed integers with width of ICPX_WIDTH (including
--              the sign bit)
-------------------------------------------------------------------------------
-- Copyright (c) 2014 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2014-01-18  1.0      wzab    Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.math_complex.all;

package icpx is
  
  constant ICPX_WIDTH : integer := 32;
  constant ICPX_INTBITS : integer := 1;

  -- constant defining the size of std_logic_vector
  -- needed to store our complex number
  constant ICPX_BV_LEN : integer := ICPX_WIDTH * 2;

  type icpx_number is record
    Re : signed(ICPX_WIDTH-1 downto 0);
    Im : signed(ICPX_WIDTH-1 downto 0);
  end record;


  type compl is record
    Re : signed(ICPX_WIDTH-1 downto 0);
    Im : signed(ICPX_WIDTH-1 downto 0);
    Ov : std_logic;
  end record;

  
   
  
  -- conversion functions
  function icpx2stlv (
    constant din : icpx_number)
    return std_logic_vector;

  function stlv2icpx (
    constant din : std_logic_vector)
    return icpx_number;

  function cplx2icpx (
    constant din : complex)
    return icpx_number;

  function icpx_zero
    return icpx_number;

  function compl_add (
    constant din1, din2: compl)
    return compl;

  function compl_sub (
    constant din1, din2: compl)
    return compl;

  function compl_mul (
    constant din1, din2: compl)
    return compl;

  function compl_div2 (
    constant din: compl)
    return compl;

  function compl_power (
    constant din: compl)
    --return unsigned(2*ICPX_WIDTH-1 downto 0);
    return unsigned;

  function compl_conjugate (
    constant din: compl)
    return compl;

  


  

  

end icpx;

package body icpx is

  function compl_mul (
    constant din1, din2 : compl)
    return compl is
    variable res : compl;
    variable re, im : signed(2 * ICPX_WIDTH-1 downto 0);
  begin
    re := (din1.Re * din2.Re) - (din1.Im * din2.Im);
    im := (din1.Re * din2.Im) + (din1.Im * din2.Re);
    -- we need to slice off 1 sign bit and INTBITS integer bits from the top
    res.Re := re(2 * ICPX_WIDTH - ICPX_INTBITS - 1 - 1 downto ICPX_WIDTH - ICPX_INTBITS - 1);
    res.Im := im(2 * ICPX_WIDTH - ICPX_INTBITS - 1 - 1 downto ICPX_WIDTH - ICPX_INTBITS - 1);
    -- propagate overflows
    res.Ov := din1.Ov or din2.Ov;
    -- if the sliced off bits are not all identical -> then an overflow occured
    for i in 0 to ICPX_INTBITS loop
      res.Ov := '1' when res.Ov = '1' or re(2 * ICPX_WIDTH - 1) /= re(2 * ICPX_WIDTH - 1 - i) or im(2 * ICPX_WIDTH - 1) /= im(2 * ICPX_WIDTH - 1 - i) else '0';
    end loop;
    return res;
  end compl_mul;


  function compl_add (
    constant din1, din2 : compl)
    return compl is
    variable res : compl;
    variable re, im : signed(ICPX_WIDTH downto 0); -- 1 extra
  begin
    re := resize(din1.Re, ICPX_WIDTH+1) + resize(din2.Re, ICPX_WIDTH+1);
    im := resize(din1.Im, ICPX_WIDTH+1) + resize(din2.Im, ICPX_WIDTH+1);
    res.Re := resize(re, ICPX_WIDTH);
    res.Im := resize(im, ICPX_WIDTH);
    -- detect overflow when 2 MSB not equal or input was overflowed
    res.Ov := '1' when din1.Ov = '1' or din2.Ov = '1' or re(ICPX_WIDTH) /= re(ICPX_WIDTH-1) or im(ICPX_WIDTH) /= im(ICPX_WIDTH-1) else '0';
    return res;
  end compl_add;

  function compl_sub (
    constant din1, din2 : compl)
    return compl is
    variable res : compl;
    variable tmp1,tmp2 : signed(ICPX_WIDTH downto 0);
    variable re, im : signed(ICPX_WIDTH downto 0); -- 1 extra
  begin
    re := resize(din1.Re, ICPX_WIDTH+1) - resize(din2.Re, ICPX_WIDTH+1);
    im := resize(din1.Im, ICPX_WIDTH+1) - resize(din2.Im, ICPX_WIDTH+1);
    res.Re := resize(re, ICPX_WIDTH);
    res.Im := resize(im, ICPX_WIDTH);
    -- detect overflow when 2 MSB not equal or input was overflowed
    res.Ov := '1' when din1.Ov = '1' or din2.Ov = '1' or re(ICPX_WIDTH) /= re(ICPX_WIDTH-1) or im(ICPX_WIDTH) /= im(ICPX_WIDTH-1) else '0';
    return res;
  end compl_sub;


  function compl_div2 (
    constant din : compl)
    return compl is
    variable res : compl;
    variable re, im : signed(ICPX_WIDTH-1 downto 0);
  begin
    res.Re := shift_right(din.Re, 1);
    res.Im := shift_right(din.Im, 1);
    res.Ov := din.Ov;
    return res;
  end compl_div2;

  function compl_power (
    constant din : compl)
    --return unsigned(2*ICPX_WIDTH-1 downto 0) is
    return unsigned is
    variable res : unsigned(2*ICPX_WIDTH-1 downto 0);
  begin
    res := unsigned(din.Re * din.Re) + unsigned(din.Im * din.Im);
--    re := to_signed(to_integer(din.Re) * to_integer(din.Re) + to_integer(din.Im) * to_integer(din.Im), 2 * ICPX_WIDTH + 1);
--    res.Re := re(2 * ICPX_WIDTH - ICPX_INTBITS -1 -1 downto ICPX_WIDTH - ICPX_INTBITS -1);
--    res.Im := to_signed(0, ICPX_WIDTH);
--    res.Ov := din.Ov;
--    for i in 0 to ICPX_INTBITS loop
--      res.Ov := '1' when res.Ov = '1' or re(2 * ICPX_WIDTH - 1) /= re(2 * ICPX_WIDTH - 1 - i) else '0';
--    end loop;
    --return res(2 * ICPX_WIDTH - 1 downto 0);-- cut the upper msb after addition
    return res;
  end compl_power;
  
  function compl_conjugate (
    constant din : compl)
    return compl is
    variable res : compl;
    variable im : signed(ICPX_WIDTH-1 downto 0);
    constant max_negative : std_logic_vector(ICPX_WIDTH-1 downto 0) := (ICPX_WIDTH-1 => '1', others => '0');
  begin
    im := - din.Im;-- to_signed(-to_integer(din.Im), ICPX_WIDTH);
    res.Re := din.Re;
    res.Im := im;
    -- negation can overflow because the negative range is one item longer than
    -- the positive range
    --res.Ov := '1' when din.Ov = '1' or im = to_signed(- 2 ** (ICPX_WIDTH-1), ICPX_WIDTH) else '0';
    res.Ov := '1' when din.Ov = '1' or std_logic_vector(im) = max_negative else '0';
    return res;
  end compl_conjugate;
  
    
  
     
    
  
  
  
  function icpx2stlv (
    constant din : icpx_number)
    return std_logic_vector is

    variable vres : std_logic_vector(2*ICPX_WIDTH-1 downto 0) :=
      (others => '0');
    
  begin  -- icpx2stlv
    vres := std_logic_vector(din.re) & std_logic_vector(din.im);
    return vres;
  end icpx2stlv;

  function stlv2icpx (
    constant din : std_logic_vector)  
    return icpx_number is

    variable vres : ICPX_NUMBER := icpx_zero;

  begin  -- stlv2icpx
    vres.Re := signed(din(2*ICPX_WIDTH-1 downto ICPX_WIDTH));
    vres.Im := signed(din(ICPX_WIDTH-1 downto 0));
    return vres;
  end stlv2icpx;

  function cplx2icpx (
    constant din : complex)  
    return icpx_number is

    variable vres : ICPX_NUMBER := icpx_zero;

  begin  -- cplx2icpx
    vres.Re := to_signed(integer(din.Re*(2.0**(ICPX_WIDTH-2))), ICPX_WIDTH);
    vres.Im := to_signed(integer(din.Im*(2.0**(ICPX_WIDTH-2))), ICPX_WIDTH);
    return vres;
  end cplx2icpx;

  function icpx_zero
    return icpx_number is

    variable vres : ICPX_NUMBER;
  begin  -- icpx_zero

    vres.Re := (others => '0');
    vres.Im := (others => '0');
    return vres;
  end icpx_zero;
  
end icpx;
