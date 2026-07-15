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

// This module slice_frames AXI Stream frames to the specified length. Smaller frames
// pass through unmodified
`timescale 1ns / 1ps
`default_nettype none

module axi_stream_frame_padder #(
  parameter int unsigned FRAME_LENGTH_WIDTH = 8,
  parameter int unsigned TDATA_WIDTH        = 1
) (
    // Usual ports
    input wire logic                            clk,
    input wire logic                            rst,

    input wire logic [ FRAME_LENGTH_WIDTH-1:0 ] frame_length,

    // Input stream
    input wire logic                            s_tvalid,
    output     logic                            s_tready,
    input wire logic [ TDATA_WIDTH-1:0 ]        s_tdata,
    input wire logic                            s_tlast,

    // Output stream
    output     logic                            m_tvalid,
    input wire logic                            m_tready,
    output     logic [ TDATA_WIDTH-1:0 ]        m_tdata,
    output     logic                            m_tlast
);

// Force not ready when we're padding
logic pad_frame;
assign s_tready = m_tready & ~pad_frame;
assign m_tvalid = pad_frame | s_tvalid;

// Slave and master strobes
wire s_axi_dv = s_tvalid & s_tready;
wire m_axi_dv = m_tvalid & m_tready;

assign m_tdata = m_tvalid ? s_tdata & { TDATA_WIDTH{ ~pad_frame } } : 'x;

logic [ FRAME_LENGTH_WIDTH-1:0 ] length_count;
logic [ FRAME_LENGTH_WIDTH-1:0 ] frame_length_reg;
wire                             m_tlast_i  = length_count >= frame_length_reg;

assign m_tlast = m_tvalid ? m_tlast_i : 'x;

always_ff @(posedge clk) begin
  if (rst) begin
    // Start length count at 1 instead of zero so we can compare with frame_length
    // without having to subtract one
    length_count <= 1;
    pad_frame    <= 1'b0;
  end else begin
    if (s_axi_dv) begin
      if (s_tlast & length_count < frame_length) begin
        pad_frame <= 1'b1;
      end
    end

    if (m_axi_dv) begin
      if (m_tlast_i) begin
        // Start length count at 1 instead of zero so we can compare with frame_length
        // without having to subtract one
        length_count <= 1;
        pad_frame    <= 1'b0;
      end else begin
        length_count <= length_count + 1;
      end
    end
  end
end

// Need to sample frame length because after the frame has completed there's
// no guarantee it will remain constant
logic first_word;
logic [ FRAME_LENGTH_WIDTH-1:0 ] frame_length_sampled;

assign frame_length_reg = first_word ? frame_length : frame_length_sampled;

always_ff @(posedge clk) begin
  if (rst) begin
    first_word <= 1'b1;
  end else begin
    if (m_axi_dv) begin
      first_word <= m_tlast_i;
      if (first_word) begin
        frame_length_sampled <= frame_length;
      end
    end
  end
end

endmodule
