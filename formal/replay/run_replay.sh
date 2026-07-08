#!/usr/bin/env bash
#
# FPGA core library
#
# Copyright 2019-2022 by Andre Souto (suoto)
# Licensed under the CERN-OHL-W v2 (https://cern.ch/cern-ohl).
# Source location: https://github.com/suoto/fpga_cores
#
# Replay the axi_stream_fifo BMC counterexample in a GHDL *simulation* and dump a
# native .ghw waveform (records preserved with named fields, unlike the smt2 VCD).
# Runs with the local GHDL (no Docker / no PSL involved here).

set -e

ROOT=$(git rev-parse --show-toplevel)
WORK="$ROOT/formal/replay/ghdl_work"
GHW="$ROOT/formal/replay/trace.ghw"
mkdir -p "$WORK"

# DUT + deps into library fpga_cores (same set/order as the .sby), then the tb.
FILES=(
  src/common_pkg.vhd
  src/sr_delay.vhd
  src/axi_stream_forward_slice.vhd
  src/axi_stream_flow_control.vhd
  src/ram_inference.vhd
  src/axi_stream_mux.vhd
  src/axi_stream_demux.vhd
  src/axi_stream_credit.vhd
  src/axi_stream_delay.vhd
  src/axi_stream_fifo_simple.vhd
  src/axi_stream_ram.vhd
  src/axi_stream_fifo.vhd
  formal/replay/axi_stream_fifo_replay_tb.vhd
)

cd "$ROOT"
GHDL_FLAGS="--std=08 -frelaxed-rules --work=fpga_cores --workdir=$WORK"

ghdl -a $GHDL_FLAGS "${FILES[@]}"
ghdl -e $GHDL_FLAGS axi_stream_fifo_replay_tb
ghdl -r $GHDL_FLAGS axi_stream_fifo_replay_tb --wave="$GHW"

echo
echo "Wrote $GHW"
echo "Open it with:  surfer $GHW    (records show as bypass.tdata/.tvalid/.tready)"
