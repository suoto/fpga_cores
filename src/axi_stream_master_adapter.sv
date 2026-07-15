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

// TODO: this will be deprecated

`timescale 1ns / 1ps
`default_nettype none

module axi_stream_master_adapter #(
  parameter int unsigned MAX_SKEW_CYCLES = 1,
  parameter int unsigned TDATA_WIDTH     = 32
) (
    // Usual ports
    input wire logic                      clk,
    input wire logic                      rst,
    // wanna-be AXI interface
    input wire logic                      wr_en,
    output     logic                      wr_full,
    output     logic                      wr_empty,
    input wire logic [ TDATA_WIDTH-1:0 ]  wr_data,
    input wire logic                      wr_last,
    // AXI master
    output     logic                      m_tvalid,
    input wire logic                      m_tready,
    output     logic [ TDATA_WIDTH-1:0 ]  m_tdata,
    output     logic                      m_tlast
);

localparam BUFFER_DEPTH = MAX_SKEW_CYCLES + 2 > 2 * MAX_SKEW_CYCLES ? MAX_SKEW_CYCLES + 2 : 2 * MAX_SKEW_CYCLES;
localparam BUFFER_DEPTH_WIDTH = $clog2( BUFFER_DEPTH );

// Stores wr_data and wr_last
logic [ TDATA_WIDTH:0 ] data_buffer [ BUFFER_DEPTH-1:0 ];

logic [ BUFFER_DEPTH_WIDTH-1:0 ] wr_ptr;
logic [ BUFFER_DEPTH_WIDTH-1:0 ] rd_ptr;
logic [ BUFFER_DEPTH_WIDTH:0 ]   ptr_diff;

// tvalid is asserted when pointers are different, regardless of tready
assign m_tvalid = |ptr_diff;
wire axi_dv     = m_tvalid & m_tready;

logic [ TDATA_WIDTH-1:0 ] m_tdata_i;
logic                     m_tlast_i;

assign { m_tlast_i, m_tdata_i } = data_buffer[ rd_ptr ];
assign m_tlast = m_tvalid ? m_tlast_i : 'x;
assign m_tdata = m_tvalid ? m_tdata_i : 'x;

// Assert the full flag whenever we run out of space to store more data. At this
// point, if the write interface doesn't respect MAX_SKEW_CYCLES *and* m_tready is
// deasserted, there will loss of data
assign wr_full  = 32'( ptr_diff ) >= BUFFER_DEPTH - MAX_SKEW_CYCLES;
assign wr_empty = ~|ptr_diff;

// Put the memory write on a separate process as it can happen irrespectively of
// reset
always_ff @(posedge clk) begin
  if (rst) begin
    wr_ptr   <= '0;
    rd_ptr   <= '0;
    ptr_diff <= '0;
  end else begin
    if (wr_en)
      data_buffer[wr_ptr] <= { wr_last, wr_data };

    if (wr_en & |ptr_diff & wr_ptr == rd_ptr)
      $error("AXI adapter overflow");

    // Update buffer occupation
    if (wr_en & ~axi_dv)
      ptr_diff <= ptr_diff + BUFFER_DEPTH_WIDTH'('d1);
    else if (~wr_en & axi_dv)
      ptr_diff <= ptr_diff - BUFFER_DEPTH_WIDTH'('d1);

    if (wr_en) begin
      // Manually wrap write pointer around BUFFER_DEPTH
      if (wr_ptr == BUFFER_DEPTH_WIDTH'(BUFFER_DEPTH - 1))
        wr_ptr <= '0;
      else
        wr_ptr <= wr_ptr + BUFFER_DEPTH_WIDTH'('d1);
    end

    if (axi_dv) begin
      // Manually wrap read pointer around BUFFER_DEPTH
      if (rd_ptr == BUFFER_DEPTH_WIDTH'(BUFFER_DEPTH - 1))
        rd_ptr <= '0;
      else
        rd_ptr <= rd_ptr + BUFFER_DEPTH_WIDTH'('d1);
    end
  end
end

endmodule
