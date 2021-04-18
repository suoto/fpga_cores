--
-- FPGA core library
--
-- Copyright 2014 by Andre Souto (suoto)
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

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

library str_format;
use str_format.str_format_pkg.all;

library fpga_cores;
use fpga_cores.common_pkg.all;

use work.testbench_utils_pkg.all;

package file_utils_pkg is

  -----------
  -- Types --
  -----------
  type file_reader_cfg_t is record
    filename : line;
    tid      : std_logic_vector;
  end record;

  type file_reader_t is record
    reader      : actor_t;
    sender      : actor_t;
    outstanding : natural;
    logger      : logger_t;
  end record;

  impure function new_file_reader(constant reader_name : in string) return file_reader_t;

  constant NULL_VECTOR : std_logic_vector(-1 downto 0) := (others => 'U');

  procedure read_file(
    signal net           : inout network_t;
    variable file_reader : inout file_reader_t;
    constant filename    : string;
    constant tid         : std_logic_vector := NULL_VECTOR;
    constant blocking    : boolean := False);

  procedure wait_all_read (
    signal net           : inout network_t;
    variable file_reader : inout file_reader_t);

  procedure wait_file_read (
    signal net           : inout network_t;
    variable file_reader : inout file_reader_t);

  impure function to_std_logic_vector(s : string) return std_logic_vector;

  -----------------
  -- Subprograms --
  -----------------
  procedure push(msg : msg_t; variable value : file_reader_cfg_t);
  impure function pop(msg : msg_t) return file_reader_cfg_t;

  alias push_file_reader_cfg is push[msg_t, file_reader_cfg_t];

  -- procedure push(
  --   msg               : msg_t;
  --   constant filename : string;
  --   constant tid      : std_logic_vector);

end file_utils_pkg;

package body file_utils_pkg is

  procedure push(
    msg               : msg_t;
    constant filename : string;
    constant tid      : std_logic_vector) is
    variable cfg      : file_reader_cfg_t(tid(tid'range));
  begin
    write(cfg.filename, filename);
    cfg.tid := tid;
    push(msg, cfg);
  end;

  procedure push(msg : msg_t; variable value : file_reader_cfg_t) is
  begin
    push(msg, value.filename.all);
    push(msg, value.tid);
  end;

  impure function pop(msg : msg_t) return file_reader_cfg_t is
    -- Pop each element like this instead of inline because we need to make sure this
    -- happens in the correct sequence
    constant filename : string           := pop_string(msg);
    constant tid      : std_logic_vector := pop(msg);
  begin
    return (filename => new string'(filename),
            tid => tid);
  end;

  -- -----------------------------------------------------------------------------------
  -- -- Helpers to deal with configuring the file reader -------------------------------
  -- -----------------------------------------------------------------------------------
  impure function new_file_reader(constant reader_name : in string) return file_reader_t is
    variable file_reader : file_reader_t;
    constant sender_name : string := "file_reader_t(" & reader_name & ")";
  begin
    return (reader      => find(reader_name),
            sender      => new_actor(sender_name),
            outstanding => 0,
            logger      => get_logger(sender_name));
  end;


  procedure read_file(
    signal net           : inout network_t;
    variable file_reader : inout file_reader_t;
    constant filename    : string;
    constant tid         : std_logic_vector := NULL_VECTOR;
    constant blocking    : boolean := False) is
    variable msg         : msg_t := new_msg;
  begin
    msg.sender := file_reader.sender;
    push(msg, filename);
    push(msg, tid);
    file_reader.outstanding := file_reader.outstanding + 1;
    send(net, file_reader.reader, msg);
    debug(file_reader.logger,
          sformat("Enqueued %s, outstanding transfers: %d", quote(filename), fo(file_reader.outstanding)));
  end;

  procedure wait_file_read (
    signal net           : inout network_t;
    variable file_reader : inout file_reader_t) is
    variable msg         : msg_t := new_msg;
  begin
    receive(net, file_reader.sender, msg);
    file_reader.outstanding := file_reader.outstanding - 1;
    debug(file_reader.logger,
          sformat("Reply received, outstanding transfers: %d", fo(file_reader.outstanding)));
  end;

  procedure wait_all_read (
    signal net           : inout network_t;
    variable file_reader : inout file_reader_t) is
    variable msg         : msg_t := new_msg;
  begin
    debug(file_reader.logger, sformat("Waiting for all files to be read. Outstanding now: %d", fo(file_reader.outstanding)));
    if file_reader.outstanding /= 0 then
      while file_reader.outstanding /= 0 loop
        wait_file_read ( net, file_reader);
      end loop;
    end if;
  end;

  impure function to_std_logic_vector(s : string) return std_logic_vector is
    variable result : std_logic_vector(4 * s'length - 1 downto 0);
  begin
    for i in s'range loop
      result(4*i - 1 downto 4*(i - 1))
        := std_logic_vector(to_unsigned(character'pos(s(i)), 4));
    end loop;
    return result;
  end;

  impure function decode_std_logic_vector_array(
    constant s          : string;
    constant data_width : integer) return std_logic_array_t is
    variable items      : lines_t := split(s, "|");
    variable data       : std_logic_array_t(0 to items'length - 1)(data_width - 1 downto 0);
  begin
    debug("decoding => '" & s & "'");
    for i in items'range loop
      data(i) := to_std_logic_vector(items(0).all);
    end loop;
    debug("done");
    return data;
  end;

end package body;
