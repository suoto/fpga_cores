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

module edge_detector #(
  parameter bit          SYNCHRONIZE_INPUT = 0,
  parameter int unsigned OUTPUT_DELAY      = 1
) (
  // Usual ports
  input wire logic clk,

  //
  input wire logic din,
  // Edges detected
  output     logic rising,
  output     logic falling,
  output     logic toggle
);

logic din_i;
if (SYNCHRONIZE_INPUT) begin : synchronize_input
  synchronizer #(
    .SYNC_STAGES (1),
    .DATA_WIDTH  (1)
  ) synchronizer_din (
    .clk  (clk),
    .din  (din),
    .dout (din_i)
  );
end else begin : dont_synchronize_input
  assign din_i = din;
end

logic din_d;
always_ff @(posedge clk) begin
  din_d <= din_i;
end

wire rising_i  = { din_d, din_i } == 2'b01;
wire falling_i = { din_d, din_i } == 2'b10;
wire toggle_i  = rising | falling;

sr_delay #(
  .DELAY_CYCLES(OUTPUT_DELAY),
  .DATA_WIDTH(3)
) sr_delay_output (
  .clk    (clk),
  .din_en (1'b1),
  .din    ( { rising_i, falling_i, toggle_i } ),
  .dout   ( { rising,   falling,   toggle } )
);

endmodule
