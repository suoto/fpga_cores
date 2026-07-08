//
// FPGA core library
//
// Copyright 2014-2021 by Andre Souto (suoto)
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

`timescale 1ns / 1ps
`default_nettype none

module synchronizer #(
    parameter int SYNC_STAGES = 2,
    parameter int DATA_WIDTH  = 1
) (
    input  wire  logic                  clk,
    input  wire  logic [ DATA_WIDTH-1:0 ] din,
    output       logic [ DATA_WIDTH-1:0 ] dout
);

logic [ DATA_WIDTH-1:0 ] din_sr [ SYNC_STAGES-1:0 ];

assign dout = din_sr[ SYNC_STAGES-1 ];

always_ff@(posedge clk)
    din_sr <= { din_sr[ SYNC_STAGES-2:0 ], din };

endmodule
