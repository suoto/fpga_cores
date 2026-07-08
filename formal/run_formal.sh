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
# Run SymbiYosys formal verification of axi_stream_fifo inside a container that
# bundles ghdl + yosys-ghdl + sby + SMT solvers. Any extra args are forwarded to
# sby (e.g. a single task:  ./run_formal.sh axi_stream_fifo.sby bmc).

set -e

PATH_TO_REPO=$(git rev-parse --show-toplevel)
# Same ghdl/synth namespace as misc/run_synth.sh's :beta image; the :formal tag
# adds SymbiYosys + solvers (z3, yices, boolector). amd64-only (emulated on arm).
CONTAINER="ghdl/synth:formal"

# Default: run all tasks (bmc + cover) of the sby file
SBY_ARGS=${*:-"-f axi_stream_fifo.sby"}

docker run                                                 \
  --rm                                                     \
  --mount type=bind,source="$PATH_TO_REPO",target=/project \
  --user "$(id -u):$(id -g)"                               \
  -w /project/formal                                       \
  "$CONTAINER" sby $SBY_ARGS
