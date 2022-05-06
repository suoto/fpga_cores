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

-- Interface type definitions

package interface_types_pkg is
  type axi_stream_debug_cfg is record
    clear_max_frame_length : std_logic;
    clear_min_frame_length : std_logic;
    clear_s_tvalid         : std_logic;
    clear_s_tready         : std_logic;
    clear_m_tvalid         : std_logic;
    clear_m_tready         : std_logic;
    block_data             : std_logic;
    allow_word             : std_logic;
    allow_frame            : std_logic;
  end record;

  type axi_stream_debug_sts is record
    word_count        : std_logic_vector;
    frame_count       : std_logic_vector;
    last_frame_length : std_logic_vector;
    min_frame_length  : std_logic_vector;
    max_frame_length  : std_logic_vector;
    s_tvalid          : std_logic;
    s_tready          : std_logic;
    m_tvalid          : std_logic;
    m_tready          : std_logic;
  end record;

end package interface_types_pkg;

