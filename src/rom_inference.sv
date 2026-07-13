//
// FPGA core library
//
// Copyright 2020-2022 by Andre Souto (suoto)
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

module rom_inference #(
  parameter int unsigned           DEPTH             = 8,
  parameter int unsigned           DATA_WIDTH        = 8,
  parameter logic [DATA_WIDTH-1:0] ROM_DATA [DEPTH],
  parameter string                 ROM_STYLE         = "auto",
  parameter int unsigned           OUTPUT_DELAY      = 1
) (
  input wire logic                       clk,
  input wire logic [ $clog2(DEPTH)-1:0 ] addr,
  output     logic                       rddata
);

(* rom_style = ROM_STYLE *)
logic [ DATA_WIDTH-1:0 ] rom [DEPTH] = ROM_DATA;
logic [ DATA_WIDTH-1:0 ] rddata_async;
wire                     invalid_addr = 32'( addr ) >= DEPTH | $isunknown( addr );

assign rddata_async = invalid_addr ? 'x : rom[addr];

sr_delay #(
  .DELAY_CYCLES (OUTPUT_DELAY),
  .DATA_WIDTH (DATA_WIDTH),
  .EXTRACT_SHREG (0)
) sr_delay_output (
  .clk    (clk),
  .din_en (1'b1),
  .din    (rddata_async),
  .dout   (rddata)
);

endmodule
