--
-- FPGA core library
--
-- Copyright 2014-2021 by Andre Souto (suoto)
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


library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

library str_format;
use str_format.str_format_pkg.all;

library fpga_cores;
use fpga_cores.common_pkg.all;

use work.testbench_utils_pkg.all;

package axi_stream_bfm_pkg is

  constant AXI_STREAM_MASTER_DEFAULT_NAME : string := "axi_stream_master_bfm";
  constant null_vector : std_logic_vector(-1 downto 0) := (others => 'U');

  type data_tuple_t is record
    tdata : std_logic_vector;
    tuser : std_logic_vector;
  end record;

  type data_tuple_array_t is array (natural range <>) of data_tuple_t;

  -- This is the user content
  type axi_stream_frame_t is record
    data        : std_logic_array_t;
    tid         : std_logic_vector;
    probability : real range 0.0 to 1.0;
  end record;

  type axi_stream_tuser_frame_t is record
    data        : data_tuple_array_t;
    tid         : std_logic_vector;
    probability : real range 0.0 to 1.0;
  end record;

  type axi_stream_bfm_t is record
    dest        : actor_t;
    sender      : actor_t;
    outstanding : natural;
    logger      : logger_t;
  end record;

  procedure push(msg : msg_t; frame : axi_stream_frame_t);
  impure function pop(msg : msg_t) return axi_stream_frame_t;
  impure function pop(msg : msg_t) return axi_stream_tuser_frame_t;
  procedure push(msg : msg_t; tuple : data_tuple_t);
  impure function pop(msg : msg_t) return data_tuple_t;

  impure function create_bfm (
    constant reader_name : in string := AXI_STREAM_MASTER_DEFAULT_NAME )
  return axi_stream_bfm_t;

  procedure axi_bfm_write (
    signal   net         : inout network_t;
    variable bfm         : inout axi_stream_bfm_t;
    constant data        : std_logic_array_t;
    constant tid         : std_logic_vector := null_vector;
    constant probability : real := 1.0;
    constant blocking    : boolean := True);

  procedure axi_bfm_write (
    signal   net         : inout network_t;
    variable bfm         : inout axi_stream_bfm_t;
    constant data        : data_tuple_array_t;
    constant tid         : std_logic_vector := null_vector;
    constant probability : real := 1.0;
    constant blocking    : boolean := True);

  procedure join (
    signal   net : inout network_t;
    variable bfm : inout axi_stream_bfm_t );

end axi_stream_bfm_pkg;

package body axi_stream_bfm_pkg is

  impure function create_bfm (
    constant reader_name : in string := AXI_STREAM_MASTER_DEFAULT_NAME ) return axi_stream_bfm_t is
    variable bfm         : axi_stream_bfm_t;
    constant sender_name : string := "axi_stream_bfm_t(" & reader_name & ")";
  begin
    return (dest        => find(reader_name),
            sender      => new_actor(sender_name),
            outstanding => 0,
            logger      => get_logger(sender_name));
  end;

  procedure push(msg : msg_t; frame : axi_stream_frame_t ) is
  begin
    push(msg, frame.probability);
    push(msg, frame.tid);
    push(msg, frame.data);
  end;

  procedure push(msg : msg_t; tuple : data_tuple_t ) is
  begin
    push(msg, tuple.tdata);
    push(msg, tuple.tuser);
  end;

  impure function pop(msg : msg_t) return data_tuple_t  is
    constant tdata : std_logic_vector:= pop(msg);
    constant tuser : std_logic_vector:= pop(msg);
  begin
    return data_tuple_t'(tdata => tdata, tuser => tuser);
  end;


  procedure push(msg : msg_t; v : data_tuple_array_t ) is
  begin
    push(msg, v'low);
    push(msg, v'high);
    for i in v'range loop
      push(msg, v(i));
    end loop;
  end;

  procedure push(msg : msg_t; frame : axi_stream_tuser_frame_t ) is
  begin
    push(msg, frame.probability);
    push(msg, frame.tid);
    push(msg, frame.data);
  end;

  impure function pop(msg : msg_t) return axi_stream_frame_t is
    constant probability : real               := pop(msg);
    constant tid         : std_logic_vector   := pop(msg);
    constant data        : std_logic_array_t  := pop(msg);
    constant frame       : axi_stream_frame_t := (data => data, tid => tid, probability => probability);
  begin
    return frame;
  end;

  impure function pop(msg : msg_t) return data_tuple_array_t is
    constant low   : integer := pop(msg);
    constant high  : integer := pop(msg);
    constant first : data_tuple_t := pop(msg);
    subtype element_array_t is
      data_tuple_array_t(low to high)(
        tdata(first.tdata'high downto first.tdata'low),
        tuser(first.tuser'high downto first.tuser'low)
      );

    variable result : element_array_t;
  begin

    result(0) := first;
    for i in result'low + 1 to result'high loop
      result(i) := data_tuple_t'(pop(msg));
    end loop;

    return result;
  end;

  impure function pop(msg : msg_t) return axi_stream_tuser_frame_t is
    constant probability : real                     := pop(msg);
    constant tid         : std_logic_vector         := pop(msg);
    constant data        : data_tuple_array_t       := pop(msg);
    constant frame       : axi_stream_tuser_frame_t := (data => data, tid => tid, probability => probability);
  begin
    return frame;
  end;

  procedure wait_reply (
    signal   net : inout network_t;
    variable bfm : inout axi_stream_bfm_t ) is
    variable msg : msg_t := new_msg(sender => bfm.sender);
  begin
    receive(net, bfm.sender, msg);
    assert pop(msg);
    bfm.outstanding := bfm.outstanding - 1;

    debug(
      bfm.logger,
      sformat(
        "Received reply, current outstanding transfers=%d",
        fo(bfm.outstanding)
      )
    );

  end;

  procedure join (
    signal   net : inout network_t;
    variable bfm : inout axi_stream_bfm_t ) is
  begin

    info(
      bfm.logger,
      sformat(
        "Waiting for %d remaing transfers to complete",
        fo(bfm.outstanding)
      )
    );

    while bfm.outstanding /= 0 loop
      wait_reply(net, bfm);
    end loop;

    info(bfm.logger, "All transfers finished");
  end;

  procedure axi_bfm_write (
    signal   net         : inout network_t;
    variable bfm         : inout axi_stream_bfm_t;
    constant data        : std_logic_array_t;
    constant tid         : std_logic_vector := null_vector;
    constant probability : real := 1.0;
    constant blocking    : boolean := True) is
    variable msg         : msg_t := new_msg(sender => bfm.sender);
  begin
    msg := new_msg(sender => bfm.sender);
    push(
      msg,
      axi_stream_frame_t'(
        data        => data,
        tid         => tid,
        probability => probability
      )
    );

    bfm.outstanding := bfm.outstanding + 1;

    send(net, bfm.dest, msg);

    if not blocking then
      return;
    end if;

    wait_reply(net, bfm);
  end;

  procedure axi_bfm_write (
    signal   net         : inout network_t;
    variable bfm         : inout axi_stream_bfm_t;
    constant data        : data_tuple_array_t;
    constant tid         : std_logic_vector := null_vector;
    constant probability : real := 1.0;
    constant blocking    : boolean := True) is
    variable msg         : msg_t := new_msg(sender => bfm.sender);
  begin
    msg := new_msg(sender => bfm.sender);
    push(
      msg,
      axi_stream_tuser_frame_t'(
        data        => data,
        tid         => tid,
        probability => probability
      )
    );

    bfm.outstanding := bfm.outstanding + 1;

    send(net, bfm.dest, msg);

    if not blocking then
      return;
    end if;

    wait_reply(net, bfm);
  end;

end package body;
