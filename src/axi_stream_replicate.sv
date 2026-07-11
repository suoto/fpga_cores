//
// FPGA core library
//
// Copyright 2016-2021 by Andre Souto (suoto)
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

// Replicate a single stream to multiple targets

module axi_stream_replicate #(
  parameter int INTERFACES  = 4,
  parameter int TDATA_WIDTH = 8
) (
    // Usual ports
    input wire logic                                       clk,
    input wire logic                                       rst,

    // AXI stream input
    input wire logic                                       s_tvalid,
    output     logic                                       s_tready,
    input wire logic [ TDATA_WIDTH-1:0 ]                   s_tdata,
    // AXI stream outputs
    output     logic [ INTERFACES-1:0 ]                    m_tvalid,
    input wire logic [ INTERFACES-1:0 ]                    m_tready,
    output     logic [ INTERFACES-1:0 ][ TDATA_WIDTH-1:0 ] m_tdata
);

wire s_axi_dv = s_tready & s_tvalid;

logic [ TDATA_WIDTH-1:0 ] s_tdata_reg;
logic [ INTERFACES-1:0 ]  m_tvalid_reg;

always_ff @(posedge clk) begin
  if (rst)
    m_tvalid_reg <= 0;
  else begin
    // Deassert tvalid of interfaces that have accepted data
    m_tvalid_reg <= m_tvalid_reg & ~m_tready;

    // Drive data to all interfaces
    if (s_axi_dv) begin
      m_tvalid_reg <= { INTERFACES{ 1'b1 } };
      s_tdata_reg  <= s_tdata;
    end
  end
end

assign s_tready = &(m_tvalid_reg & m_tready) | ~|m_tvalid_reg;
assign m_tvalid = m_tvalid_reg;

for (genvar i = 0; i < INTERFACES; i++) begin : gen_tdata
  assign m_tdata[i] = m_tvalid[i] ? s_tdata_reg : 'x;
end

endmodule
