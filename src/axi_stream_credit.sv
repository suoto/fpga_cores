//
// FPGA core library
//
// Copyright 2022 by Andre Souto (suoto)
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

module axi_stream_credit #(
  parameter  int unsigned CREDITS     = 8,
  parameter  int unsigned TDATA_WIDTH = 16,
  localparam int unsigned CREDITS_WIDTH = $clog2(CREDITS + 1)
) (
    input wire logic                       clk,
    input wire logic                       rst,

    input wire logic                       credit_return_en,
    input wire logic [ CREDITS_WIDTH-1:0 ] credit_return,
    output     logic [ CREDITS_WIDTH-1:0 ] credits_available,

    // AXI slave input
    input wire logic                       s_tvalid,
    output     logic                       s_tready,
    input wire logic [ TDATA_WIDTH-1:0 ]   s_tdata,

    // AXI master output
    output     logic                       m_tvalid,
    input wire logic                       m_tready,
    output     logic [ TDATA_WIDTH-1:0 ]   m_tdata
);

wire  s_data_valid = s_tvalid & s_tready;

logic [ CREDITS_WIDTH-1:0 ] credits_available_delta ;
always_comb begin
  credits_available_delta = '0;
  case ({ s_data_valid, credit_return_en })
    { 1'b1, 1'b0 }: credits_available_delta = ( CREDITS_WIDTH )'(-1); // consume 1 credit
    { 1'b0, 1'b1 }: credits_available_delta = credit_return;          // only returning credit
    { 1'b1, 1'b1 }: credits_available_delta = credit_return - 1;      // return and consume
    default       : credits_available_delta = '0;
  endcase
end

wire [ CREDITS_WIDTH-1:0 ] credits_available_next = credits_available + credits_available_delta;

always_ff @(posedge clk) begin
  if (rst) begin
    credits_available <= (CREDITS_WIDTH)'(CREDITS);
  end else begin
    credits_available <= credits_available_next;
  end
end

wire enable = |(credits_available) | ( credit_return_en & credit_return > 0 );
axi_stream_flow_control #(
  .DATA_WIDTH (TDATA_WIDTH)
) axi_stream_flow_control_u (
  .enable   (enable),

  .s_tvalid (s_tvalid),
  .s_tready (s_tready),
  .s_tdata  (s_tdata),

  .m_tvalid (m_tvalid),
  .m_tready (m_tready),
  .m_tdata  (m_tdata)
);

credit_overflow_check : assert property (
  @(posedge clk) disable iff (rst)
  ( credit_return_en && credit_return != 0) |-> ( credits_available != ( CREDITS_WIDTH )' ( CREDITS ) )
) else $error("Credit overflow");

endmodule
