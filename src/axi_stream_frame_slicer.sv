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

module axi_stream_frame_slicer #(
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

logic [ FRAME_LENGTH_WIDTH-1:0 ] length_count;
wire                             m_tlast_i = length_count < frame_length - 1 ? s_tlast : 1'b1;

assign s_tready = m_tready;

assign m_tvalid = s_tvalid;
assign m_tdata  = m_tvalid ? s_tdata   : 'x;
assign m_tlast  = m_tvalid ? m_tlast_i : 'x;

wire axi_dv = s_tvalid & m_tready;
always_ff @(posedge clk) begin
  if (rst)
    length_count <= '0;
  else begin
    if (axi_dv) begin
      if (m_tlast_i) begin
        length_count <= '0;
      end else begin
        length_count <= length_count + 1;
      end
    end
  end
end

endmodule
