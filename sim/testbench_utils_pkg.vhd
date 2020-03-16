--
-- DVB IP
--
-- Copyright 2019 by Suoto <andre820@gmail.com>
--
-- This file is part of the DVB IP.
--
-- DVB IP is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- DVB IP is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with DVB IP.  If not, see <http://www.gnu.org/licenses/>.

use std.textio.all;

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

library str_format;
use str_format.str_format_pkg.all;

use work.common_pkg.all;
use work.dvb_utils_pkg.all;

package testbench_utils_pkg is

  type file_pair_t is record
    input : string(1 to 512);
    reference : string(1 to 512);
  end record;

  type file_pair_array_t is array (natural range <>) of file_pair_t;

  type config_t is record
    constellation : constellation_t;
    frame_type    : frame_type_t;
    code_rate     : code_rate_t;
    files         : file_pair_t;
  end record;

  type config_array_t is array (natural range <>) of config_t;

  function to_string( constant config : config_t ) return string;
  function to_string( constant config : file_pair_t ) return string;
  impure function to_string (
    constant source : std_logic_vector_2d_t;
    constant width  : integer := 16) return string;

  -- Add double quotes around a string
  function quote ( constant s : string ) return string;
  function quote ( constant s : character ) return string;

  impure function get_test_cfg ( constant str : string) return config_array_t;
  impure function get_test_cfg ( constant str : string) return file_pair_array_t;

  procedure push(msg : msg_t; value : constellation_t);
  procedure push(msg : msg_t; value : frame_type_t);
  procedure push(msg : msg_t; value : code_rate_t);

  impure function pop(msg : msg_t) return constellation_t;
  impure function pop(msg : msg_t) return frame_type_t;
  impure function pop(msg : msg_t) return code_rate_t;

  procedure push(msg : msg_t; value : std_logic_vector_2d_t);
  impure function pop(msg : msg_t) return std_logic_vector_2d_t;

end testbench_utils_pkg;

package body testbench_utils_pkg is

  procedure push(msg : msg_t; value : constellation_t) is
  begin
    -- Push value as a string
    push(msg.data, constellation_t'image(value));
  end;

  procedure push(msg : msg_t; value : frame_type_t) is
  begin
    -- Push value as a string
    push(msg.data, frame_type_t'image(value));
  end;

  procedure push(msg : msg_t; value : code_rate_t) is
  begin
    -- Push value as a string
    push(msg.data, code_rate_t'image(value));
  end;


  impure function pop(msg : msg_t) return constellation_t is
  begin
    return constellation_t'value(pop(msg.data));
  end;

  impure function pop(msg : msg_t) return frame_type_t is
  begin
    return frame_type_t 'value(pop(msg.data));
  end;

  impure function pop(msg : msg_t) return code_rate_t is
  begin
    return code_rate_t'value(pop(msg.data));
  end;


  --
  impure function get_test_cfg ( constant str : string)
  return config_array_t is
    variable cfg_strings : lines_t := split(str, "|");
    variable cfg_items   : lines_t;
    variable result      : config_array_t(0 to cfg_strings'length - 1);
    variable current     : config_t;
  begin

    if cfg_strings'length = 0 then
      warning("Could not parse any config from " & quote(str));
      return result;
    end if;

    for i in 0 to cfg_strings'length - 1 loop
      cfg_items := split(cfg_strings(i).all, ",");
      
      if cfg_items'length /= 5 then
        failure("Malformed config string " & quote(cfg_strings(i).all));
      end if;

      current.constellation := constellation_t'value(cfg_items(0).all);
      current.frame_type := frame_type_t'value(cfg_items(1).all);
      current.code_rate := code_rate_t'value(cfg_items(2).all);
      current.files.input := (others => nul);
      current.files.reference := (others => nul);

      current.files.input(cfg_items(3).all'range) := cfg_items(3).all;
      current.files.reference(cfg_items(4).all'range) := cfg_items(4).all;

      result(i) := current;

    end loop;

    info("Parsed " & integer'image(result'length) & " configuration(s):");
    for i in result'range loop
      info("- " & integer'image(i) & ": " & to_string(result(i)));
    end loop;

    return result;

  end function get_test_cfg;

  impure function get_test_cfg ( constant str : string) return file_pair_array_t is
    variable cfg_strings : lines_t := split(str, "|");
    variable cfg_items   : lines_t;
    variable result      : file_pair_array_t(0 to cfg_strings'length - 1);
    variable current     : config_t;
  begin

    if cfg_strings'length = 0 then
      warning("Could not parse any config from " & quote(str));
      return result;
    end if;

    for i in 0 to cfg_strings'length - 1 loop
      cfg_items := split(cfg_strings(i).all, ",");
      
      if cfg_items'length /= 2 then
        failure("Malformed config string " & quote(cfg_strings(i).all));
      end if;

      result(i) := (input => cfg_items(0).all,
                    reference => cfg_items(1).all);

    end loop;

    info("Parsed " & integer'image(result'length) & " configuration(s):");
    for i in result'range loop
      info("- " & integer'image(i) & ": " & to_string(result(i)));
    end loop;

    return result;

  end function get_test_cfg;

  -- Add double quotes around a string
  function quote ( constant s : character ) return string is
  begin
    return '"' & s & '"';
  end;

  function quote ( constant s : string ) return string is
  begin
    return '"' & s & '"';
  end function quote;

  -- Returns a string representation of config_t
  function to_string( constant config : config_t ) return string is
  begin
    return "config("
      & "constellation=" & quote(constellation_t'image(config.constellation)) & ", "
      & "frame_type=" & quote(frame_type_t'image(config.frame_type)) & ", "
      & "code_rate=" & quote(code_rate_t'image(config.code_rate)) & ", "
      & "input=" & quote(config.files.input) & ", "
      & "reference=" & quote(config.files.reference) & ")";
  end function to_string;

  -- Returns a string representation of config_t
  function to_string( constant config : file_pair_t ) return string is
  begin
    return "file_pair("
      & "input=" & quote(config.input) & ", "
      & "reference=" & quote(config.reference) & ")";
  end function to_string;

  impure function to_string (
    constant source      : std_logic_vector_2d_t;
    constant width       : integer := 16) return string is
    variable result      : line;
    constant num_lines   : integer := (source'length + width - 1) / width;
    constant items_width : integer := 3 + (source(0)'length + 3) / 4;
    constant col_0_width : integer := integer'image(source'length)'length;
    variable item_cnt    : integer := 0;
    begin
      write(result, cr & string'(1 to col_0_width + 3 => ' '));

      for i in 0 to width - 1 loop
        write(result, sformat("%" & integer'image(items_width) & "d  ", fo(i)));
      end loop;

      while item_cnt < source'length loop
        write(result, cr & sformat("%" & integer'image(col_0_width) & "d   ", fo(item_cnt)));
        for i in 0 to width - 1 loop
          if item_cnt < source'length then
            write(result, sformat("%" & integer'image(items_width) & "r  ", fo(source(item_cnt))));
          else
            exit;
          end if;
          item_cnt := item_cnt + 1;
        end loop;
      end loop;

      return result.all;
    end function to_string;


  procedure push(msg : msg_t; value : std_logic_vector_2d_t) is
  begin
    push(msg, value'low);
    push(msg, value'high);

    for i in value'low to value'high loop
      push(msg, value(i));
    end loop;

  end;

  impure function pop(msg : msg_t) return std_logic_vector_2d_t is
    constant low    : integer := pop(msg);
    constant high   : integer := pop(msg);
    constant first  : std_logic_vector := pop(msg);
    constant width  : integer := first'length;
    variable result : std_logic_vector_2d_t(low to high)(width - 1 downto 0);
  begin

    result(0) := first;

    for i in low to high - 1 loop
      result(i + 1) := pop(msg);
    end loop;

    return result;
  end;

end package body;
