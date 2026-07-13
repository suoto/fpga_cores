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

module axi_stream_arbiter #(
    parameter string       MODE            = "ROUND_ROBIN", // ROUND_ROBIN, INTERLEAVED, ABSOLUTE
    parameter int unsigned INTERFACES      = 4,
    parameter int unsigned DATA_WIDTH      = 8,
    parameter bit          REGISTER_INPUTS = 0
) (
    // Usual ports
    input wire logic                                      clk,
    input wire logic                                      rst,

    output     logic [ INTERFACES-1:0 ]                   selected,

    // AXI slave input
    input wire logic [ INTERFACES-1:0 ]                   s_tvalid,
    output     logic [ INTERFACES-1:0 ]                   s_tready,
    input wire logic [ INTERFACES-1:0 ][ DATA_WIDTH-1:0 ] s_tdata,
    input wire logic [ INTERFACES-1:0 ]                   s_tlast,

    // AXI master output
    output     logic                                      m_tvalid,
    input wire logic                                      m_tready,
    output     logic [ DATA_WIDTH-1:0 ]                   m_tdata,
    output     logic                                      m_tlast
);

`define keep_first_bit_set(v) ((v) & (-(v)))

`ifndef FORMAL
  if (~(MODE inside {"ROUND_ROBIN", "INTERLEAVED", "ABSOLUTE"}))
    $fatal(1, { "Invalid arbiter mode:", MODE });
`endif

// AXI slave input
logic [ INTERFACES-1:0 ]                   s_tvalid_i;
logic [ INTERFACES-1:0 ]                   s_tready_i;
logic [ INTERFACES-1:0 ][ DATA_WIDTH-1:0 ] s_tdata_i;
logic [ INTERFACES-1:0 ]                   s_tlast_i;

// Optionally sample inputs
for(genvar i = 0; i < INTERFACES; i++) begin : prepare_inputs
  if( REGISTER_INPUTS ) begin : register_inputs
    axi_stream_forward_slice #(
      .TDATA_WIDTH(DATA_WIDTH + 1)
    ) axi_stream_forward_slice_u (
      .clk      (clk),
      .rst      (rst),

      .s_tvalid (s_tvalid[i]),
      .s_tready (s_tready[i]),
      .s_tdata  ({ s_tlast[i], s_tdata[i] }),

      .m_tvalid (s_tvalid_i[i]),
      .m_tready (s_tready_i[i]),
      .m_tdata  ({ s_tlast_i[i], s_tdata_i[i] })
    );
  end else begin : dont_register_inputs
      assign s_tvalid_i[i] = s_tvalid[i];
      assign s_tdata_i[i]  = s_tdata[i];
      assign s_tlast_i[i]  = s_tlast[i];

      assign s_tready[i]   = s_tready_i[i];
  end
end

logic [ INTERFACES-1:0 ] selection_mask;
logic [ DATA_WIDTH-1:0 ] m_tdata_i;
logic                    m_tlast_i;
axi_stream_mux #(
  .INTERFACES (INTERFACES),
  .DATA_WIDTH (DATA_WIDTH + 1)
) axi_stream_mux_u (
  .selection_mask (selection_mask),

  .s_tvalid       (s_tvalid_i),
  .s_tready       (s_tready_i),
  .s_tdata        ({ s_tlast_i, s_tdata_i }),

  .m_tvalid       (m_tvalid),
  .m_tready       (m_tready),
  .m_tdata        ({ m_tlast_i, m_tdata_i })
);

assign m_tdata = m_tvalid ? m_tdata_i : 'x;
assign m_tlast = m_tvalid ? m_tlast_i : 'x;

wire [ INTERFACES-1:0 ] s_data_valid = s_tvalid_i & s_tready_i;
wire                    m_data_valid = m_tvalid & m_tready;

logic                    arbitrate;
logic [ INTERFACES-1:0 ] selected_reg;

// Common process
always_ff @(posedge clk) begin
  if (rst) begin
      arbitrate    <= 1'b1;
      selected_reg <= '0;
  end else begin
    selected_reg <= selected;

    // Arbitrate at the first word of every frame only
    if (m_data_valid)
      arbitrate <= m_tlast_i;
    else if (|s_tvalid_i)
      arbitrate <= 1'b0;
    end
end

if (MODE == "ABSOLUTE" ) begin : absolute_logic
  assign selected = arbitrate ? `keep_first_bit_set(s_tvalid_i)
                              : selected_reg;
end

if ( MODE == "INTERLEAVED" ) begin : interleaved_logic
  logic [ INTERFACES-1:0 ] selected_next;

  assign selected = arbitrate ? selected_next : selected_reg;

  always_ff @(posedge clk) begin
    if (rst) begin
      selected_next    <= '0;
      selected_next[0] <= 1'b1;
    end else begin
      if (arbitrate & |s_tvalid_i)
        selected_next <= { selected_next[ INTERFACES - 2:0 ], selected_next[ INTERFACES - 1 ] };
    end
  end
end

if ( MODE == "ROUND_ROBIN" ) begin : round_robin_logic
  // Rotating priority round-robin: after serving interface N, priority rotates
  // so that N+1 has highest priority, wrapping around. This ensures no interface
  // is permanently advantaged by its index position.
  logic [ $clog2(INTERFACES)-1:0 ] last_grant_id;
  wire  [ INTERFACES-1:1 ]         mask = { (INTERFACES-1){1'b1} } << last_grant_id;

  wire [ 2*INTERFACES-2:0 ] candidates_wide = { s_tvalid_i, s_tvalid_i[ INTERFACES-1:1 ] & mask };
  wire [ 2*INTERFACES-2:0 ] chosen_wide = `keep_first_bit_set(candidates_wide);

  assign selected = arbitrate ? chosen_wide[ 2*INTERFACES - 2 : INTERFACES - 1 ] | { chosen_wide[ INTERFACES - 2 : 0 ], 1'b0 }
                              : selected_reg;

  wire [ $clog2(INTERFACES)-1:0 ] selected_id;
  one_hot_to_decimal #( .WIDTH(INTERFACES)) one_hot_to_decimal_u (
    .in  (selected),
    .out (selected_id)
  );

  always_ff @(posedge clk) begin
    if (rst)
      last_grant_id <= { $clog2(INTERFACES){ 1'b1 } };
    else
      if (m_data_valid & m_tlast)
        last_grant_id <= selected_id;
  end

end

endmodule
