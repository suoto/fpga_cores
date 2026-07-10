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

// Shift register based delay
module sr_delay #(
    parameter int DELAY_CYCLES  = 2,
    parameter int DATA_WIDTH    = 8,
    parameter bit EXTRACT_SHREG = 1
) (
    input wire logic clk,

    input wire logic                    din_en,
    input wire logic [ DATA_WIDTH-1:0 ] din,
    output     logic [ DATA_WIDTH-1:0 ] dout
);

if (DELAY_CYCLES == 0) begin : no_delay
  assign dout = din;

end else begin : non_zero_delay
  (* SHREG_EXTRACT = EXTRACT_SHREG ? "yes"  : "no" *)
  (* ASYNC_REG     = EXTRACT_SHREG ? "TRUE" : "FALSE" *)
  logic [DATA_WIDTH-1:0] din_sr [DELAY_CYCLES-1:0];

  assign dout = din_sr[ DELAY_CYCLES - 1 ];

  always_ff @(posedge clk) begin
    if (din_en)
      din_sr <= { din_sr[ DELAY_CYCLES - 2:0 ], din };
  end
end

endmodule
