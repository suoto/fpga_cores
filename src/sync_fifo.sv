//
// FPGA core library
//
// Copyright 2016-2022 by Andre Souto (suoto)
//
// This source describes Open Hardware and is licensed under the CERN-OHL-W v2

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

module sync_fifo #(
  parameter string       RAM_TYPE           = "auto",
  parameter int unsigned DEPTH              = 512,
  parameter int unsigned DATA_WIDTH         = 8,
  parameter int unsigned UPPER_TRESHOLD     = 510,
  parameter int unsigned LOWER_TRESHOLD     = 10,
  parameter int unsigned EXTRA_OUTPUT_DELAY = 0
) (
    input wire logic                     clk,
    input wire logic                     rst,

    // Status
    output     logic                     full,
    output     logic                     upper,
    output     logic                     lower,
    output     logic                     empty,

    input wire logic                     wr_en,
    input wire logic [ DATA_WIDTH-1:0 ]  wr_data,

    // Read port
    input wire logic                     rd_en,
    output     logic [ DATA_WIDTH-1:0 ]  rd_data,
    output     logic                     rd_dv
);

logic [ $clog2(DEPTH)-1:0 ] wr_ptr;
logic [ $clog2(DEPTH)-1:0 ] rd_ptr;
logic [ $clog2(DEPTH)-1:0 ] ptr_diff;


logic rd_dv_reg; // Read data valid (registered)

logic inc_wr_ptr;
logic inc_rd_ptr;

logic [ DATA_WIDTH-1:0 ] rd_data_i; // Fifo read data

  //-----------------
  // Port mappings --
  //-----------------
ram_inference #(
.DEPTH        (DEPTH),
.DATA_WIDTH   (DATA_WIDTH),
.RAM_STYLE    (RAM_TYPE),
.OUTPUT_DELAY (EXTRA_OUTPUT_DELAY)
) ram_inference_u (
  // Port A
  .clk_a    (clk),
  .en_a     (1'b1),
  .wren_a   (wr_en),
  .addr_a   (wr_ptr),
  .wrdata_a (wr_data),
  .rddata_a (),

  // Port B
  .clk_b    (clk),
  .en_b     (1'b1),
  .addr_b   (rd_ptr),
  .rddata_b (rd_data_i)
);

assign full     = ptr_diff == ($clog2(DEPTH))'(DEPTH - 1);
assign empty    = ~|ptr_diff;

assign inc_wr_ptr = wr_en & ~full;
assign inc_rd_ptr = rd_en & ~empty;

// Set thresholds
assign upper      = ptr_diff >= ($clog2(DEPTH))'(UPPER_TRESHOLD);
assign lower      = ptr_diff <= ($clog2(DEPTH))'(LOWER_TRESHOLD);

if (EXTRA_OUTPUT_DELAY == 0) begin : no_extra_output_delay
  assign rd_dv = inc_rd_ptr;
end else begin : extra_output_delay
  assign rd_dv = rd_dv_reg;
end

assign rd_data = rd_dv ? rd_data_i : 'x;

always_ff @(posedge clk) begin
  if (rst) begin
    wr_ptr    <= '0;
    rd_ptr    <= '0;
    ptr_diff  <= '0;
    rd_dv_reg <= 1'b0;
  end else begin

      rd_dv_reg <= 1'b0;

      if (inc_wr_ptr & ~inc_rd_ptr)
        ptr_diff <= ptr_diff + 1;
      else if (~inc_wr_ptr & inc_rd_ptr)
        ptr_diff <= ptr_diff - 1;

      if (inc_wr_ptr) begin
        wr_ptr <= wr_ptr + 1;
      end

      if (inc_rd_ptr) begin
        rd_dv_reg <= 1'b1;
        rd_ptr    <= rd_ptr + 1;
      end
  end
end

// Fire once at the start of each overflow episode
ap_no_overflow : assert property (
  @(posedge clk) disable iff (rst)
  !$rose(full && wr_en)
) else $warning("FIFO overflow");

// Reset behaviour check
ap_empty_on_reset : assert property (
  @(posedge clk) $rose(rst) |-> empty === 1'b1
) else $error("Empty should be '1' upon reset, got '%b'", empty);

ap_full_on_reset : assert property (
  @(posedge clk) $rose(rst) |-> full === 1'b0
) else $error("Full should be '0' upon reset, got '%b'", full);

endmodule
