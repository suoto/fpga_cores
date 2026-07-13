//
// FPGA core library
//
// Copyright 2020-2021 by Andre Souto (suoto)
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

// Converts a one-hot encoded input into its decimal index. Assumes the input is
// always one-hot; the datapath is a flat OR-encoder with no priority logic. An
// all-zero input yields 0. Non one-hot inputs are flagged in simulation only.
`timescale 1ns / 1ps

module one_hot_to_decimal #(
    parameter  int unsigned WIDTH  = 8
) (
    input  wire logic [ WIDTH-1:0 ]         in,
    output      logic [ $clog2(WIDTH)-1:0 ] out
);

  always_comb begin
    out = '0;
    for (int i = 0; i < WIDTH; i++)
      out |= { $clog2( WIDTH ){ in[i] } } & i[ $clog2(WIDTH)-1:0 ];
  end

always_comb
  assert (in == '0 || $onehot(in))
    else $error("one_hot_to_decimal: input 0x%0h is not one-hot", in);

endmodule
