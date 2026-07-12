#!/usr/bin/env bash
#
# FPGA core library
#
# Copyright 2019-2022 by Andre Souto (suoto)
#
# This source describes Open Hardware and is licensed under the CERN-OHL-W v2
#
# You may redistribute and modify this documentation and make products using it
# under the terms of the CERN-OHL-W v2 (https:/cern.ch/cern-ohl).This
# documentation is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY,
# INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A
# PARTICULAR PURPOSE. Please see the CERN-OHL-W v2 for applicable conditions.
#
# Source location: https://github.com/suoto/fpga_cores
#
# Run SymbiYosys formal verification of axi_stream_fifo in two stages:
#
#   1. sv2v translates the idiomatic-SystemVerilog DUT (packed multidim arrays,
#      `string`/unpacked-array params, '{...} patterns) to Verilog-2005, which
#      yosys' native frontend reads without complaint. sv2v runs natively on the
#      host (macOS/Linux binary from github.com/zachjs/sv2v/releases) -- it is a
#      text-to-text pass, so no container is needed for this stage.
#   2. yosys/sby prove the design. The SVA properties live in the untouched
#      formal wrapper and are read by yosys' native `read_verilog -sv -formal`
#      (see axi_stream_fifo.sby); neither sv2v nor yosys-slang support temporal
#      SVA, so the wrapper deliberately bypasses stage 1.
#
# Any extra args are forwarded to sby (e.g. a single task:
#   ./run_formal.sh -f axi_stream_fifo.sby bmc).

set -e

PATH_TO_REPO=$(git rev-parse --show-toplevel)
# Native (arm64) image: yosys + SymbiYosys + SMT solvers.
CONTAINER="suoto/fpga-cores:formal"
# Host sv2v binary (override with SV2V=/path/to/sv2v if not on PATH).
SV2V=${SV2V:-sv2v}

# DUT sources, in dependency order (leaves -> top). common_pkg_sv.sv is omitted:
# its only DUT use (is_valid_ram_type) has an `input string` arg sv2v can't lower,
# so ram_inference.sv guards that check behind `ifndef FORMAL (defined below).
DUT_SRCS=(
  src/sr_delay.sv
  src/ram_inference.sv
  src/axi_stream_forward_slice.sv
  src/axi_stream_delay.sv
  src/axi_stream_fifo.sv
)

BUILD_REL=formal/build
mkdir -p "$PATH_TO_REPO/$BUILD_REL"

# --- Stage 1: sv2v preprocess (native host) --------------------------------
echo "sv2v: translating DUT -> $BUILD_REL/dut.v"
( cd "$PATH_TO_REPO" && "$SV2V" -DFORMAL "${DUT_SRCS[@]}" ) > "$PATH_TO_REPO/$BUILD_REL/dut.v"

# --- Stage 2: yosys/sby formal (native) ------------------------------------
# Default: run all tasks (bmc + cover) of the sby file
SBY_ARGS=${*:-"-f axi_stream_fifo.sby"}

docker run                                                 \
  --rm                                                     \
  --mount type=bind,source="$PATH_TO_REPO",target=/project \
  --user "$(id -u):$(id -g)"                               \
  -w /project/formal                                       \
  "$CONTAINER" sby $SBY_ARGS
