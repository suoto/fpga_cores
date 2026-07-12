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

// is_valid_ram_type takes an `input string`, which sv2v cannot lower to
// Verilog-2005 (no string type) -> excluded from the formal flow, which defines
// FORMAL and always drives a legal RAM_STYLE.
`ifndef FORMAL
  import common_pkg_sv::is_valid_ram_type;
`endif

`timescale 1ns / 1ps
`default_nettype none

module ram_inference #(
    parameter int unsigned           DEPTH                 = 16,
    parameter int unsigned           DATA_WIDTH            = 16,
    parameter string                 RAM_STYLE             = "auto",
    parameter logic [DATA_WIDTH-1:0] INITIAL_VALUE [DEPTH] = '{default: '0},
    parameter int unsigned           OUTPUT_DELAY          = 1
) (
    // Port A
    input wire logic                       clk_a,
    input wire logic                       en_a,
    input wire logic                       wren_a,
    input wire logic [ $clog2(DEPTH)-1:0 ] addr_a,
    input wire logic [ DATA_WIDTH-1:0 ]    wrdata_a,
    output     logic [ DATA_WIDTH-1:0 ]    rddata_a,

    // Port B
    input wire logic                       clk_b,
    input wire logic                       en_b,
    input wire logic [ $clog2(DEPTH)-1:0 ] addr_b,
    output     logic [ DATA_WIDTH-1:0 ]    rddata_b
);

`ifndef FORMAL
  if (~is_valid_ram_type(RAM_STYLE)) begin : check_ram_style
    $fatal(1, { "Invalid RAM_TYLE", RAM_STYLE });
  end
`endif

(* ram_style = RAM_STYLE *)
reg [ DATA_WIDTH-1:0 ] ram [DEPTH]; // = INITIAL_VALUE;

`ifndef FORMAL
  wire invalid_addr_a = 32'( addr_a ) >= DEPTH | $isunknown( addr_a );
  wire invalid_addr_b = 32'( addr_b ) >= DEPTH | $isunknown( addr_b );
`else
  wire invalid_addr_a = 32'( addr_a ) >= DEPTH;
  wire invalid_addr_b = 32'( addr_b ) >= DEPTH;
`endif

wire [ DATA_WIDTH-1:0 ] rddata_a_async = invalid_addr_a ? 'x : ram[ addr_a ];
wire [ DATA_WIDTH-1:0 ] rddata_b_async = invalid_addr_b ? 'x : ram[ addr_b ];

sr_delay #(
  .DELAY_CYCLES  (OUTPUT_DELAY),
  .DATA_WIDTH    (DATA_WIDTH),
  .EXTRACT_SHREG (0)
) sr_delay_rddata_a (
  .clk    (clk_a),
  .din_en (en_a),
  .din    (rddata_a_async),
  .dout   (rddata_a)
);

sr_delay #(
  .DELAY_CYCLES  (OUTPUT_DELAY),
  .DATA_WIDTH    (DATA_WIDTH),
  .EXTRACT_SHREG (0)
) sr_delay_rddata_b (
  .clk    (clk_b),
  .din_en (en_b),
  .din    (rddata_b_async),
  .dout   (rddata_b)
);

always_ff @(posedge clk_a) begin
  if (wren_a ) begin
    ram[ addr_a ] <= wrdata_a;
  end
end

endmodule
