//
// FPGA core library
//
// Copyright 2020-2021 by Andre Souto (suoto)
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

module axi_stream_mux #(
    parameter int INTERFACES = 4,
    parameter int DATA_WIDTH = 8
) (
    input wire logic [ INTERFACES-1:0 ]                   selection_mask,

    input wire logic [ INTERFACES-1:0 ]                   s_tvalid,
    output     logic [ INTERFACES-1:0 ]                   s_tready,
    input wire logic [ INTERFACES-1:0 ][ DATA_WIDTH-1:0 ] s_tdata,

    output     logic                                      m_tvalid,
    input wire logic                                      m_tready,
    output     logic [ DATA_WIDTH-1:0 ]                   m_tdata
);

logic [ DATA_WIDTH-1:0 ] m_tdata_mux;

assign s_tready = selection_mask & { INTERFACES{ m_tready } };

assign m_tdata   = ( $isunknown( selection_mask ) | ~|selection_mask ) ? { DATA_WIDTH{ 1'bX } } : m_tdata_mux;
assign m_tvalid  =   $isunknown( selection_mask )                      ? 1'bX                   : |( s_tvalid & selection_mask );

always_comb begin
  m_tdata_mux = '0;
  for(int i = 0; i < INTERFACES; i++) begin
    m_tdata_mux |= s_tdata[i] & { DATA_WIDTH{ selection_mask[ i ] } };
  end
end

endmodule

