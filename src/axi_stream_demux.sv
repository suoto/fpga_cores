//
// FPGA core library
//
// Copyright 2016-2022 by Andre Souto (suoto)
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

module axi_stream_demux #(
  parameter int unsigned INTERFACES = 4,
  parameter int unsigned DATA_WIDTH = 1
) (
    input wire logic [ INTERFACES-1:0 ]                   selection_mask,

    input wire logic                                      s_tvalid,
    output     logic                                      s_tready,
    input wire logic [ DATA_WIDTH-1:0 ]                   s_tdata,

    output     logic [ INTERFACES-1:0 ]                   m_tvalid,
    input wire logic [ INTERFACES-1:0 ]                   m_tready,
    output     logic [ INTERFACES-1:0 ][ DATA_WIDTH-1:0 ] m_tdata
);

assign m_tvalid = { INTERFACES{ s_tvalid } } & selection_mask;
assign s_tready = |{ m_tready & selection_mask };

for (genvar i=0; i < INTERFACES; i++) begin : assign_tdata
  assign m_tdata[i] = m_tvalid[i] ? s_tdata : 'x;
end

endmodule
