//
// FPGA core library
//
// Copyright 2014-2022 by Andre Souto (suoto)
//
// This source describes Open Hardware and is licensed under the CERN-OHL-W v2
//
// You may redistribute and modify this documentation and make products using it
// under the terms of the CERN-OHL-W v2 (https:/cern.ch/cern-ohl).This
// documentation is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY,
// INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A
// PARTICULAR PURPOSE. Please see the CERN-OHL-W v2 for applicable conditions.
//
// Source location: https://github.com/suoto/fpga_cores
//
// As per CERN-OHL-W v2 section 4.1, should You produce hardware based on these
// sources, You must maintain the Source Location visible on the external case
// of the FPGA Cores or other product you make using this documentation.

// Common helper functions shared across the fpga_cores library
`timescale 1ns / 1ps

package common_pkg_sv;

  // Returns true if ram_style is a value accepted by Vivado. See UG901 for details.
  function automatic bit is_valid_ram_type(input string ram_style);
    return ram_style inside {"block", "distributed", "registers", "ultra", "mixed", "auto"};
  endfunction

endpackage
