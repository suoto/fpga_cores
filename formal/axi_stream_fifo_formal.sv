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

// Formal verification wrapper for axi_stream_fifo (SystemVerilog).
//
// The DUT source is left untouched: all properties live here as SVA and are only
// elaborated by yosys' native SV frontend under `read_verilog -sv -formal` (see
// formal/axi_stream_fifo.sby). Under normal cocotb/verilator sim they are inert.
//
// The free formal inputs (s_tvalid, s_tdata, s_tlast, m_tready) are top-level ports
// so yosys/sby drives them freely; clk/rst are ports too. Everything the DUT drives
// stays internal so we can reference it in the properties, and is pinned with
// `(* keep *)` so it survives `prep` and stays under the axi_stream_fifo_formal
// scope for formal/decode_trace.py.
//
// NOTE (WIP RTL): on this branch src/axi_stream_fifo.sv has its ptr_diff
// increment/decrement commented out, so ptr_diff is stuck at 0 -> m_tvalid is
// always 0 and nothing is ever emitted. Consequently BMC PASSES (interface/status
// props hold; data_integrity holds vacuously) but the cover tasks below are
// UNREACHABLE / FAIL until the pointer logic is restored. That is expected.

`timescale 1ns / 1ps
`default_nettype none

module axi_stream_fifo_formal #(
    // Small depth keeps BMC fast; `full` compares against FIFO_DEPTH directly so
    // any depth is legal (no more numbits() width-coincidence workaround).
    parameter int unsigned FIFO_DEPTH = 4,
    parameter int unsigned DATA_WIDTH = 8
) (
    input wire logic                      clk,
    input wire logic                      rst,
    // Free formal inputs (arbitrary legal master / receiver)
    input wire logic                      s_tvalid,
    input wire logic [ DATA_WIDTH-1:0 ]   s_tdata,
    input wire logic                      s_tlast,
    input wire logic                      m_tready
);

  // DUT outputs / internal observables (kept so all observed signals live under
  // axi_stream_fifo_formal in the trace).
  (* keep *) logic                            s_tready;
  (* keep *) logic                            m_tvalid;
  (* keep *) logic [ DATA_WIDTH-1:0 ]         m_tdata;
  (* keep *) logic                            m_tlast;
  (* keep *) logic                            empty;
  (* keep *) logic                            full;
  (* keep *) logic [ $clog2( FIFO_DEPTH ):0 ] entries;

  // Scoreboard: input/output beat counters (ramp method). Because the master is
  // constrained (below) to always drive s_tdata = wr_expected, proving the n-th
  // output equals rd_expected proves in-order, corruption-free data transfer.
  (* keep *) logic [ DATA_WIDTH-1:0 ] wr_expected;
  (* keep *) logic [ DATA_WIDTH-1:0 ] rd_expected;

  axi_stream_fifo #(
      .FIFO_DEPTH(FIFO_DEPTH),
      .DATA_WIDTH(DATA_WIDTH),
      .RAM_STYLE ("auto")
  ) dut (
      .clk      (clk),
      .rst      (rst),
      .entries  (entries),
      .empty    (empty),
      .full     (full),
      .s_tvalid (s_tvalid),
      .s_tready (s_tready),
      .s_tdata  (s_tdata),
      .s_tlast  (s_tlast),
      .m_tvalid (m_tvalid),
      .m_tready (m_tready),
      .m_tdata  (m_tdata),
      .m_tlast  (m_tlast)
  );

  // Count accepted input beats
  always_ff @(posedge clk) begin
    if (rst)                          wr_expected <= '1;
    else if (s_tvalid && s_tready)    wr_expected <= wr_expected + 1;
  end

  // Count delivered output beats
  always_ff @(posedge clk) begin
    if (rst)                          rd_expected <= '1;
    else if (m_tvalid && m_tready)    rd_expected <= rd_expected + 1;
  end

  // ---------------------------------------------------------------------------
  // Properties -- immediate assertions in a clocked block.
  //
  // yosys' native (read_verilog) SV frontend does NOT parse concurrent SVA
  // (assert property, |->, |=>, sequences). It only accepts immediate
  // assert/assume/cover inside a clocked always block, with $past/$stable for
  // temporal reasoning; everything below is written in that style.
  // ---------------------------------------------------------------------------

  // $past is only meaningful once an edge has been seen: 0 in the initial state,
  // 1 forever after the first posedge. Gate every temporal check on it.
  logic f_past_valid = 1'b0;
  always_ff @(posedge clk) f_past_valid <= 1'b1;

  always_ff @(posedge clk) begin
    // Reset shaping: rst asserted only in the initial state, deasserted after
    // (one reset cycle at t=0, then run free).
    assume (rst == !f_past_valid);

    if (f_past_valid && !rst) begin
      // --- Master model: constrain the free inputs to a legal AXI master ----
      // Hold valid/data/last stable while backpressured. The !$past(rst) guard
      // restores SVA `disable iff (rst)` semantics: a |=> property spans two
      // cycles, so it must be skipped when the antecedent cycle was in reset
      // (otherwise $past reaches into the reset state and fires spuriously).
      if (!$past(rst) && $past(s_tvalid && !s_tready)) begin
        assume (s_tvalid);
        assume (s_tdata == $past(s_tdata));
        assume (s_tlast == $past(s_tlast));
      end
      // Master drives the ramp value the scoreboard expects.
      if (s_tvalid)
        assume (s_tdata == wr_expected);

      // --- DUT must obey AXI-stream on its master port ----------------------
      // Hold valid/data/last stable while backpressured (no dropped/mutated beat).
      if (!$past(rst) && $past(m_tvalid && !m_tready)) begin
        assert (m_tvalid);
        assert (m_tdata == $past(m_tdata));
        assert (m_tlast == $past(m_tlast));
      end

      // Status can never be simultaneously empty and full.
      assert (!(empty && full));

      // Data integrity: the n-th delivered beat equals the n-th accepted one.
      if (m_tvalid && m_tready)
        assert (m_tdata == rd_expected);

      // --- Reachability (cover) --------------------------------------------
      // NOTE (WIP RTL): unreachable until axi_stream_fifo's ptr_diff logic is
      // restored (nothing is emitted today); see header note.
      cover (full);
      cover (m_tvalid && m_tready);
    end
  end

endmodule

`default_nettype wire
