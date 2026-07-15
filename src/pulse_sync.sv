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

// Synchronizes a pulse between different clock domains
`timescale 1ns / 1ps
`default_nettype none

module pulse_sync #(
  parameter int unsigned EXTRA_DELAY_CYCLES = 1
) (
    // Usual ports
    input wire logic  src_clk,
    input wire logic  src_pulse,

    input wire logic  dst_clk,
    output     logic  dst_pulse
);

logic pulse_toggle;

always_ff @(posedge src_clk) begin
  if (src_pulse)
    pulse_toggle <= ~pulse_toggle;
end

edge_detector #(
  .SYNCHRONIZE_INPUT (1),
  .OUTPUT_DELAY (EXTRA_DELAY_CYCLES)
) edge_detector_u (
  .clk     (dst_clk),

  //
  .din     (pulse_toggle),
  // Edges detected
  .rising  (),
  .falling (),
  .toggle  (dst_pulse)
);


endmodule
