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

`timescale 1ns / 1ps
`default_nettype none

module axi_stream_fifo #(
  parameter int unsigned FIFO_DEPTH                = 10,
  parameter int unsigned DATA_WIDTH                = 8,
  parameter int unsigned EXTRA_OUTPUT_DELAY_CYCLES = 0,
  parameter string       RAM_STYLE                 = "auto"
) (
  // Usual ports
  input wire logic                            clk,
  input wire logic                            rst,

  // status
  output     logic [ $clog2( FIFO_DEPTH ):0 ] entries,
  output     logic                            empty,
  output     logic                            full,

  // Write side
  input wire logic                            s_tvalid,
  output     logic                            s_tready,
  input wire logic [ DATA_WIDTH-1:0 ]         s_tdata,
  input wire logic                            s_tlast,  // TODO: remove

  // Read side
  output     logic                            m_tvalid,
  input wire logic                            m_tready,
  output     logic [ DATA_WIDTH-1:0 ]         m_tdata,
  output     logic                            m_tlast  // TODO: remove
);

wire s_axi_dv = s_tready & s_tvalid;
wire m_axi_dv;

logic [ $clog2( FIFO_DEPTH ):0 ] ptr_diff;
logic [ $clog2( FIFO_DEPTH ):0 ] ram_wr_ptr;
logic [ $clog2( FIFO_DEPTH ):0 ] ram_rd_ptr;

always_ff @(posedge clk) begin
  if (rst) begin
    ptr_diff      <= 0;
    ram_wr_ptr    <= 0;
    ram_rd_ptr    <= 0;
  end else begin
    // Handle write pointer increment (FIFO_DEPTH is not necessarily a power of 2)
    if (s_axi_dv)
      ram_wr_ptr <= (ram_wr_ptr == FIFO_DEPTH - 1) ? 0 : ram_wr_ptr + 1;

    // Handle read pointer increment (FIFO_DEPTH is not necessarily a power of 2)
    if (m_axi_dv)
      ram_rd_ptr <= (ram_rd_ptr == FIFO_DEPTH - 1) ? 0 : ram_rd_ptr + 1;

    // Calculate the pointer difference without using the actual pointers; FIFO_DEPTH is
    // not necessarily a power of 2
    if (s_axi_dv & ~m_axi_dv)
      ptr_diff <= ptr_diff + 1;
    else if (~s_axi_dv & m_axi_dv)
      ptr_diff <= ptr_diff - 1;
  end
end

wire [ $clog2( FIFO_DEPTH )-1:0 ] ram_wr_addr = ram_wr_ptr[ $clog2( FIFO_DEPTH )-1:0 ];
wire [ $clog2( FIFO_DEPTH )-1:0 ] ram_rd_addr = ram_rd_ptr[ $clog2( FIFO_DEPTH )-1:0 ];

logic                    ram_tvalid;
logic                    ram_tready;
logic [ DATA_WIDTH-1:0 ] ram_tdata;
logic                    ram_tlast;

ram_inference #(
  .DEPTH        ( FIFO_DEPTH ),
  .DATA_WIDTH   ( DATA_WIDTH + 1 ),
  .RAM_STYLE    ( RAM_STYLE ),
  .OUTPUT_DELAY ( 0 ) // We'll add delays outside of the RAM code
) ram_inference_u (
  // Port A
  .clk_a    (clk),
  .en_a     (1'b1),
  .wren_a   (s_axi_dv),
  .addr_a   (ram_wr_addr),
  .wrdata_a ({ s_tlast, s_tdata }),
  .rddata_a (),

  // Port B
  .clk_b    (clk),
  .en_b     (1'b1),
  .addr_b   (ram_rd_addr),
  .rddata_b ({ ram_tlast, ram_tdata })
);

assign m_axi_dv = ram_tready & ram_tvalid;

axi_stream_delay #(
  .DELAY_CYCLES ( EXTRA_OUTPUT_DELAY_CYCLES ),
  .TDATA_WIDTH  ( DATA_WIDTH + 1)
) axi_stream_delay_output (
  .clk      (clk),
  .rst      (rst),

  .s_tvalid (ram_tvalid),
  .s_tready (ram_tready),
  .s_tdata  ({ ram_tlast, ram_tdata }),

  .m_tvalid (m_tvalid),
  .m_tready (m_tready),
  .m_tdata  ({ m_tlast, m_tdata })
);

// Read when ram is not full and pointer diff is not 0
assign ram_tvalid = |ptr_diff;
assign s_tready = ~full;

assign entries = ptr_diff;
assign empty   = ~|ptr_diff;                    // FIFO is empty when the output adapter is empty and ptr diff is 0
assign full    = 32'( ptr_diff ) == FIFO_DEPTH; // Full when ptr_diff equals FIFO depth, i.e., delta is all 0s

endmodule
