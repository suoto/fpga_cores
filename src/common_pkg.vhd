--
-- FPGA core library
--
-- Copyright 2014-2022 by Andre Souto (suoto)
--
-- This source describes Open Hardware and is licensed under the CERN-OHL-W v2
--
-- You may redistribute and modify this documentation and make products using it
-- under the terms of the CERN-OHL-W v2 (https:/cern.ch/cern-ohl).This
-- documentation is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY,
-- INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A
-- PARTICULAR PURPOSE. Please see the CERN-OHL-W v2 for applicable conditions.
--
-- Source location: https://github.com/suoto/fpga_cores
--
-- As per CERN-OHL-W v2 section 4.1, should You produce hardware based on these
-- sources, You must maintain the Source Location visible on the external case
-- of the FPGA Cores or other product you make using this documentation.

use std.textio.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package common_pkg is

  -- This should work for ModelSim, GHDL, Xilinx and Altera
  constant IS_SIMULATION : boolean :=
      False
      -- pragma translate_off
      -- synthesis translate_off
      or True
      -- synthesis translate_on
      -- pragma translate_on
      ;

  type ram_type_t is (auto, bram, lut, uram);
  type std_logic_array_t is array (natural range <>) of std_logic_vector; -- Needs VHDL 2008 in Vivado
  type unsigned_array_t is array (natural range <>) of unsigned; -- Needs VHDL 2008 in Vivado
  type integer_vector_t is array (natural range <>) of integer;
  type integer_array_t is array (natural range <>) of integer_vector_t;

  function to_string( constant v : integer_vector_t ) return string;

  -- Calculates the number of bits required to represent a given value
  function numbits (constant v : natural) return natural;

  -- Add double quotes around a string
  function quote ( constant s : string ) return string;
  function quote ( constant s : character ) return string;

  -- Gray <-> Binary conversion
  function bin_to_gray (bin  : std_logic_vector) return std_logic_vector;
  function bin_to_gray (bin  : unsigned) return unsigned;
  function gray_to_bin (gray : std_logic_vector) return std_logic_vector;
  function gray_to_bin (gray : unsigned) return unsigned;

  function mirror_bytes (constant v : std_logic_vector) return std_logic_vector;
  function mirror_bits (constant v : std_logic_vector) return std_logic_vector;

  function minimum(constant a, b : integer) return integer;
  function minimum(constant values : integer_vector_t) return integer;
  function to_boolean( v : std_ulogic) return boolean;
  function from_boolean( v : boolean ) return std_ulogic;

  function max (constant a, b : integer) return integer;
  function max (constant v : integer_vector_t) return integer;

  function sum (constant v : integer_vector_t) return integer;

  function to_01_sim (constant v : std_logic) return std_logic;
  function to_01_sim (constant v : std_logic_vector) return std_logic_vector;

  function get_field (
    constant v      : in std_logic_vector;
    constant index  : in natural;
    constant widths : in integer_vector_t
  ) return            std_logic;

  function get_field (
    constant v      : in std_logic_vector;
    constant index  : in natural;
    constant widths : in integer_vector_t) return std_logic_vector;

  constant BRAM_SIZE     : integer := 18 * 1024;
  constant BRAM_TRESHOLD : real    := 1.5;

  function get_ram_style (
    constant ram_type   : ram_type_t;
    constant addr_width : natural;
    constant data_width : natural) return string;

  function one_hot_to_decimal ( constant v : std_logic_vector) return unsigned;
  function decimal_to_one_hot ( constant v : std_logic_vector ) return std_logic_vector;
  function has_undefined ( constant v : std_logic_vector ) return boolean;
  function has_undefined ( constant v : unsigned ) return boolean;


  function get_table_entry_width ( v : std_logic_array_t ) return integer;

end common_pkg;

package body common_pkg is

  ------------------------------------------------------------------------------------
  -- Calculates the number of bits required to represent a given value
  function numbits ( constant v : natural ) return natural is
  begin
    if v <= 1 then
      return 1;
    end if;

    return integer(ceil(log2(real(v))));
  end function numbits;

  ------------------------------------------------------------------------------------
  function mirror_bytes ( constant v : std_logic_vector )
  return std_logic_vector is
      constant byte_number : natural := v'length / 8;
      variable result      : std_logic_vector(v'length - 1 downto 0);
  begin
      assert byte_number * 8 = v'length
          report "Can't swap bytes with a non-integer number of bytes. " &
                 "Argument has " & integer'image(v'length)
          severity Failure;

      for byte in 0 to byte_number - 1 loop
          result((byte_number - byte) * 8 - 1 downto (byte_number - byte - 1) * 8) := v((byte + 1) * 8 + v'low - 1 downto byte * 8 + v'low);
      end loop;
      return result;
  end function mirror_bytes;

  ------------------------------------------------------------------------------------
  function mirror_bits (constant v : std_logic_vector) return std_logic_vector is
    variable result : std_logic_vector(v'length - 1 downto 0);
  begin

    for i in 0 to v'length - 1 loop
      result(v'length - i - 1) := v(i + v'low);
    end loop;

    return result;
  end;

  ------------------------------------------------------------------------------------
  function minimum(constant a, b : integer) return integer is
  begin
    return minimum(integer_vector_t'(a, b));
  end;

  ------------------------------------------------------------------------------------
  function minimum(constant values : integer_vector_t) return integer is
    variable result : integer := integer'high;
  begin
    assert values'length /= 0
      report "Can't get minimum from an empty sequence"
      severity Error;

    for index in values'range loop

      if values(index) < result then
        result := values(index);
      end if;

    end loop;

    return result;
  end;

  --------------------------------------------------------------------------------------
  function to_boolean( v : std_ulogic) return boolean is begin
    case v is
      when '0' | 'L'   => return (false);
      when '1' | 'H'   => return (true);
      when others      => return (false);
    end case;
  end to_boolean;

  --------------------------------------------------------------------------------------
  function from_boolean( v : boolean) return std_ulogic is begin
    if v then
      return '1';
    end if;
    return '0';
  end from_boolean;

  --------------------------------------------------------------------------------------
  function max (constant a, b : integer) return integer is
  begin
    return max((a, b));
  end;

  --------------------------------------------------------------------------------------
  function max (constant v : integer_vector_t) return integer is
    variable result : integer := integer'low;
  begin
    assert v'length /= 0
      report "Can't get maximum from an empty sequence"
      severity Error;

    for i in v'range loop
      if v(i) > result then
        result := v(i);
      end if;
    end loop;
    return result;
  end;

  --------------------------------------------------------------------------------------
  function sum (constant v : integer_vector_t) return integer is
    variable sum : natural;
  begin
    for i in v'range loop
      sum := sum + v(i);
    end loop;

    return sum;
  end;

  --------------------------------------------------------------------------------------
  -- Gray <-> Binary conversion
  function bin_to_gray (
               bin  : std_logic_vector) return std_logic_vector is
      variable gray : std_logic_vector(bin'range);
  begin
      gray(gray'high) := bin(bin'high);
      for i in bin'high - 1 downto 0 loop
          gray(i) := bin(i + 1) xor bin(i);
      end loop;
      return gray;
  end function bin_to_gray;

  --------------------------------------------------------------------------------------
  function gray_to_bin (
               gray : std_logic_vector) return std_logic_vector is
      variable bin  : std_logic_vector(gray'range);
  begin
      bin(bin'high) := gray(gray'high);
      for i in gray'high - 1 downto 0 loop
          bin(i) := bin(i + 1) xor gray(i);
      end loop;
      return bin;
  end function gray_to_bin;

  --------------------------------------------------------------------------------------
  function bin_to_gray (bin  : unsigned) return unsigned is
  begin
      return unsigned(bin_to_gray(std_logic_vector(bin)));
  end bin_to_gray;

  --------------------------------------------------------------------------------------
  function gray_to_bin (gray : unsigned) return unsigned is
  begin
      return unsigned(gray_to_bin(std_logic_vector(gray)));
  end gray_to_bin;

  --------------------------------------------------------------------------------------
  -- Add double quotes around a string
  function quote ( constant s : character ) return string is
  begin
    return '"' & s & '"';
  end;

  --------------------------------------------------------------------------------------
  function quote ( constant s : string ) return string is
  begin
    return '"' & s & '"';
  end function quote;

  --
  function to_string(
    constant v : integer_vector_t) return string is
    variable L : line;
  begin
    for i in v'range loop
      write(L, integer'image(i) & " => " & integer'image(v(i)));
      if i /= v'length - 1 then
        write(L, string'(", "));
      end if;
    end loop;

    return "(" & L.all & ")";
  end;

  -- Replace v'ascending to work around GHDL limitation
  function ascending ( constant v : integer_vector_t ) return boolean is
  begin
    if v'right > v'left then
      return True;
    end if;
    return False;
  end;

  -- Extracts a field from a std_logic_vector composed of multiple concatenated fields
  function get_field (
    constant v      : in std_logic_vector;
    constant index  : in natural;
    constant widths : in integer_vector_t
  ) return            std_logic_vector is
    variable lsb    : integer := 0;
    variable msb    : integer := 0;
  begin

    assert sum(widths) = v'length
      report "Conflicting widths: sum(widths) = " & integer'image(sum(widths)) &
             " but v'length is " & integer'image(v'length)
      severity Failure;

    if index > 0 then
      if widths'ascending then
        lsb := sum(widths(widths'left to index - 1));
      else
        lsb := sum(widths(index - 1 downto widths'right));
      end if;
    end if;

    -- Account for v not starting at 0
    lsb := lsb + v'low;

    msb := lsb + widths(index);

    assert widths(index) + lsb <= v'length + v'low
      report "Width vector " & to_string(widths) & " can't address a vector whose width is " & integer'image(v'length)
      severity Failure;

    if v'ascending then
      return v(lsb to msb - 1);
    else
      return v(msb - 1 downto lsb);
    end if;
  end;

  -- Extracts a field from a std_logic_vector composed of multiple concatenated fields
  function get_field (
    constant v      : in std_logic_vector;
    constant index  : in natural;
    constant widths : in integer_vector_t
  ) return            std_logic is
    constant result : std_logic_vector := get_field(v => v, index => index, widths => widths);
  begin

    -- synthesis translate_off
    assert widths(index) = 1
      report "Associated width when extracting std_logic must be 1 but got " & to_string(widths(index))
      severity Error;
    -- synthesis translate_on

    return result(result'low);
  end;

  function to_01_sim (constant v : std_logic) return std_logic is
  begin
    -- synthesis translate_off
    return to_01(v);
    -- synthesis translate_on
    return v;
  end;

  function to_01_sim (constant v : std_logic_vector) return std_logic_vector is
  begin
    -- synthesis translate_off
    return to_01(v);
    -- synthesis translate_on
    return v;
  end;

  --
  function resolve_ram_type (constant ram_type : ram_type_t) return string is
  begin
    case ram_type is
      when bram => return "block";
      when lut => return "distributed";
      when others => return ram_type_t'image(ram_type);
    end case;
  end;

  -- Define RAM style based on the size if ram_type is set to auto
  -- Assign block RAM if the rom size is bigger than 150% of a 18KB block RAM
  function get_ram_style (
    constant ram_type   : ram_type_t;
    constant addr_width : natural;
    constant data_width : natural) return string is
    constant size       : natural := (2**ADDR_WIDTH) * DATA_WIDTH;
  begin
    if ram_type /= auto  then
      return resolve_ram_type(ram_type);
    end if;

    if real(size / BRAM_SIZE) > BRAM_TRESHOLD then
      return resolve_ram_type(bram);
    end if;

    return resolve_ram_type(lut);

  end function get_ram_style;

  function has_undefined ( constant v : std_logic_vector ) return boolean is
  begin
    -- This is only relevant in simulation
    if not IS_SIMULATION then return False; end if;

    if xor(v) = 'U' then return True; end if;
    if xor(v) = 'X' then return True; end if;

    return False;
  end;

  function has_undefined ( constant v : unsigned ) return boolean is
  begin
    return has_undefined(std_logic_vector(v));
  end;

  function one_hot_to_decimal ( constant v : std_logic_vector) return unsigned is
    constant width : integer := numbits(v'length);
    variable mux : unsigned(width - 1 downto 0);
  begin
    if v = (v'range => '0') then
      return (width - 1 downto 0 => 'U');
    end if;

    mux := (others => '0');
    for i in v'range loop
      mux := mux or (to_unsigned(i, width) and (width - 1 downto 0 => v(i)));
    end loop;
    return mux;
  end;

  function decimal_to_one_hot ( constant v : std_logic_vector ) return std_logic_vector is
    variable result : std_logic_vector(2**v'length - 1 downto 0);
  begin
    result                          := (others => '0');
    result(to_integer(unsigned(v))) := '1';
    return result;
  end function;

  -- Gets the width of the elements in an array
  function get_table_entry_width ( v : std_logic_array_t ) return integer is
    constant element : std_logic_vector := v(v'low);
  begin
    return element'length;
  end;


end package body;
