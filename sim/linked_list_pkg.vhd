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


use std.textio.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

library str_format;
use str_format.str_format_pkg.all;

package linked_list_pkg is
  generic (type type_t);

  -- To iterate
  type array_t is array (natural range <>) of type_t;

  -- Create the linked list core record and a pointer to it
  type link_t;
  type ptr_t is access link_t;
  type link_t is record
    data     : type_t;
    next_ptr : ptr_t;
  end record;

  -- Double linked list core API
  type linked_list_t is protected
    -- General push back/front for non access types or records not containing access types
    -- elements
    procedure push_back (constant item : in type_t);
    -- procedure push_front(constant item : in type_t);

    -- Specific push back for access types or records containing access types elements
    procedure push_back_access (variable item : inout type_t);
    -- procedure push_front_access (variable item : inout type_t);

    impure function pop_front return type_t;
    -- impure function pop_back return type_t;

    impure function front return type_t;
    impure function back return type_t;

    impure function get(index : natural) return type_t;
    impure function items return array_t;
    impure function size return integer;
    impure function empty return boolean;
    procedure clear;
  end protected;

end linked_list_pkg;

package body linked_list_pkg is

  type linked_list_t is protected body
    variable m_tail   : ptr_t := null;
    variable m_head   : ptr_t := null;
    variable m_size   : natural := 0;
    constant m_logger : logger_t := get_logger("linked_list_logger");

    -- Adds an element to the end of the list
    procedure push_back (constant item : in type_t) is -- {{ -----------------------------------------------
      variable new_item : ptr_t;
      variable node     : ptr_t;
    begin
      new_item      := new link_t;
      new_item.data := item;

      if m_tail = null then
        m_tail        := new_item;
      else
        node          := m_tail;
        node.next_ptr := new_item;
        m_tail        := m_tail.next_ptr;
      end if;

      if m_head = null and m_size = 0 then
        m_head := m_tail;
      end if;

      m_size := m_size + 1;
    end; -- }}

    -- Adds an element to the beginning of the list
    procedure push_front (constant item : in type_t) is -- {{ ----------------------------------------------
      variable new_item : ptr_t;
      variable node     : ptr_t;
    begin
      new_item      := new link_t;
      new_item.data := item;

      if m_head = null then
        m_head        := new_item;
      else
        node          := m_head;
        node.next_ptr := new_item;
        m_head        := m_head.next_ptr;
      end if;

      if m_head = null and m_size = 0 then
        m_head := m_head;
      end if;

      m_size := m_size + 1;
    end; -- }}

    -- Access type capable method to add element to the end of the list
    procedure push_back_access (variable item : inout type_t) is -- {{ -------------------------------------
      variable new_item : ptr_t;
      variable node     : ptr_t;
    begin
      new_item      := new link_t;
      new_item.data := item;

      if m_tail = null then
        m_tail        := new_item;
      else
        node          := m_tail;
        node.next_ptr := new_item;
        m_tail        := m_tail.next_ptr;
      end if;

      if m_head = null and m_size = 0 then
        m_head := m_tail;
      end if;

      m_size := m_size + 1;
    end; -- }}

    -- Access type capable method to add element to the end of the list
    procedure push_front_access (variable item : inout type_t) is -- {{ ------------------------------------
      variable new_item : ptr_t;
      variable node     : ptr_t;
    begin
      new_item      := new link_t;
      new_item.data := item;

      if m_head = null then
        m_head        := new_item;
      else
        node          := m_head;
        node.next_ptr := new_item;
        m_head        := m_head.next_ptr;
      end if;

      if m_head = null and m_size = 0 then
        m_head := m_head;
      end if;

      m_size := m_size + 1;

    end; -- }}

    impure function pop_front return type_t is -- {{ -------------------------------------------------------
      variable node : ptr_t;
      variable item : type_t;
    begin
      -- assert m_head /= null and m_size /= 0
      --   report "List is empty"
      --   severity Failure;

      node   := m_head;
      m_head := m_head.next_ptr;
      item   := node.data;
      deallocate(node);

      m_size    := m_size - 1;

      return item;

    end; -- }}

    impure function pop_back return type_t is -- {{ --------------------------------------------------------
      variable node : ptr_t;
      variable item : type_t;
    begin
      -- assert m_tail /= null and m_size /= 0
      --   report "List is empty"
      --   severity Failure;

      node   := m_tail;
      m_tail := m_tail.next_ptr;
      item   := node.data;
      deallocate(node);

      m_size    := m_size - 1;

      return item;

    end; -- }}

    impure function front return type_t is -- {{ -----------------------------------------------------------
    begin
      return m_head.data;
    end; -- }}

    impure function back return type_t is -- {{ ------------------------------------------------------------
    begin
      return m_tail.data;
    end; -- }}

    impure function get(index : natural) return type_t is -- {{ --------------------------------------------
      variable current : ptr_t;
    begin
      current := m_head;

      for i in 0 to index - 1 loop
        current := current.next_ptr;
      end loop;

      return current.data;
    end; -- }}

    impure function items return array_t is -- {{ ----------------------------------------------------------
      variable list    : array_t(0 to m_size - 1);
      variable current : ptr_t;
    begin
      if m_size = 0 then
        return list;
      end if;

      current := m_head;

      for i in 0 to m_size - 1 loop
        list(i) := current.data;
        current := current.next_ptr;
      end loop;

      return list;
    end; -- }}

    impure function empty return boolean is -- {{ ----------------------------------------------------------
    begin
      return m_size = 0;
    end; -- }}

    impure function size return integer is -- {{ -----------------------------------------------------------
    begin
      return m_size;
    end; -- }}

    procedure clear is -- {{ -------------------------------------------------------------------------------
      variable item : type_t;
    begin
      while not empty loop
        item := pop_front;
      end loop;

      assert m_size = 0;
      assert m_tail = null;
      assert m_head = null;

    end; -- }}

  end protected body;

end package body;
