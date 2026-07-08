//
// FPGA core library
//
// Copyright 2019-2021 by Andre Souto (suoto)
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

module axi_stream_forward_slice #(
  parameter int TDATA_WIDTH = 8
) (
  // Usual ports
  input wire logic clk,
  input wire logic rst,

  // AXI slave input
  input wire logic                     s_tvalid,
  output     logic                     s_tready,
  input wire logic [ TDATA_WIDTH-1:0 ] s_tdata,

  // AXI master output
  output     logic                     m_tvalid,
  input wire logic                     m_tready,
  output     logic [ TDATA_WIDTH-1:0 ] m_tdata
);

assign s_tready = m_tready | ~m_tvalid;

always_ff @(posedge clk) begin
  if (m_tready) begin
    m_tvalid <= 0;
    // Force m_tdata for Xs to make sure data is not used when m_tvalid is 0
    m_tdata  <= { TDATA_WIDTH{ 1'bX } };
  end

  if (s_tvalid & s_tready) begin
    m_tvalid <= 1;
    m_tdata  <= s_tdata;
  end

  if (rst) begin
    m_tvalid <= 0;
  end
end


endmodule
