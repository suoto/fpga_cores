//
// FPGA core library
//
// Copyright 2019-2021 by Andre Souto (suoto)
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

module axi_stream_delay #(
  parameter int DELAY_CYCLES = 4,
  parameter int TDATA_WIDTH = 8
) (
  // Usual ports
  input wire logic                     clk,
  input wire logic                     rst,

  // AXI slave input
  input wire logic                     s_tvalid,
  output     logic                     s_tready,
  input wire logic [ TDATA_WIDTH-1:0 ] s_tdata,

  // AXI master output
  output     logic                     m_tvalid,
  input wire logic                     m_tready,
  output     logic [ TDATA_WIDTH-1:0 ] m_tdata
);

logic [ TDATA_WIDTH-1:0 ] tdata_pipe  [ DELAY_CYCLES:0 ];
logic                     tvalid_pipe [ DELAY_CYCLES:0 ];
logic                     tready_pipe [ DELAY_CYCLES:0 ];

assign tvalid_pipe[0] = s_tvalid;
assign tdata_pipe[0]  = s_tdata;
assign s_tready       = tready_pipe[0];

for (genvar i = 0; i < DELAY_CYCLES; i++) begin : slices
  axi_stream_forward_slice #(
    .TDATA_WIDTH(TDATA_WIDTH)
  ) u_axi_stream_forward_slice  (
    .clk      (clk),
    .rst      (rst),

    .s_tvalid (tvalid_pipe[ i ]),
    .s_tready (tready_pipe[ i ]),
    .s_tdata  (tdata_pipe[ i ]),

    .m_tvalid (tvalid_pipe[ i+1 ]),
    .m_tready (tready_pipe[ i+1 ]),
    .m_tdata  (tdata_pipe[ i+1 ])
  );
end

assign m_tvalid                    = tvalid_pipe[ DELAY_CYCLES ];
assign m_tdata                     = tdata_pipe[ DELAY_CYCLES ];
assign tready_pipe[ DELAY_CYCLES ] = m_tready;

endmodule
