# CLAUDE.md

This file provides guidance to AI agents when working with code in this
repository.

## What this is

A library of reusable, mostly synthesizable VHDL-2008 cores for FPGAs (FIFOs,
AXI-Stream infrastructure, memory inference wrappers, etc.), plus simulation
helpers and VUnit testbenches. Open hardware under CERN-OHL-W v2 — every source
file carries the license header and must keep the source-location notice (see
`templates/entity.vhd`).

## Layout

- `src/` — synthesizable RTL, compiled into VHDL library `fpga_cores`.
  `src/exponential_golomb/` is a separate library `exp_golomb`.
- `sim/` — non-synthesizable simulation helpers (BFMs, file readers/comparators,
  linked list, contexts), library `fpga_cores_sim`. `sim_context.vhd` is a VHDL
  context that testbenches `use`.
- `testbench/` — VUnit testbenches, library `tb`. One `*_tb.vhd` per core.
- `dependencies/hdl_string_format` — git submodule, library `str_format`. Run
  `git submodule update --init --recursive` before building.
- `run.py` — VUnit run script; the single source of truth for libraries,
  compile/sim flags, and parametrized test configs.
- `misc/` — Docker wrappers for CI (`run_tests.sh`, `run_synth.sh`,
  `yosys/synth.ys`).

## Build / test / synth

Tests run under VUnit via `run.py`. The two practical entry points:

- Dockerized (matches CI, needs only Docker): `misc/run_tests.sh [vunit args]`
  e.g. `misc/run_tests.sh --num-threads 4`
- Direct (needs a VHDL simulator — GHDL, NVC, or ModelSim — plus VUnit/OSVVM
  installed): `./run.py [vunit args]`

Common VUnit invocations (pass through either entry point):

- List all tests: `./run.py --list`
- Run one test/config by glob: `./run.py "*axi_stream_fifo_tb*"`
- Run a single named test: `./run.py "lib.entity.test_name"`
- Open waveforms in the GUI: `./run.py -g "*pattern*"` (uses `wave.do`)
- `--seed N` pins the random seed (printed at startup; defaults to random each
  run).

Synthesis smoke-test (Yosys + ghdl plugin, Dockerized): `misc/run_synth.sh`.
Note `misc/yosys/synth.ys` lists its source files explicitly and only elaborates
`axi_stream_width_converter` — update it if you add files to that synthesis
target.

## How testing works (read before touching tests)

- `run.py` declares libraries and, crucially, generates **parametrized test
  configurations** in `addTests()` and its helpers. Adding a new testbench means
  wiring it up here (at minimum to pass `seed`); adding generic sweeps (data
  widths, depths, clock periods) also goes here, not in the VHDL.
- Several testbenches consume binary stimulus/reference files that `run.py`
  **generates on the fly** into `vunit_out/` (see
  `generateAxiFileReaderTestFile` and the `addAxiFileCompare*` /
  `addAxiFileReader*` helpers). Regeneration is keyed off file mtime vs `run.py`
  mtime. If stimulus looks stale, delete `vunit_out/`.
- Testbenches use VUnit (`runner_cfg`, `run("test_name")`, `test_runner_setup`),
  OSVVM `RandomPType` for randomization (seeded via the `seed` generic), and the
  `fpga_cores_sim.sim_context` context. The `-- vunit: run_all_in_same_sim`
  pragma at the top of a TB runs all its tests in one simulation.
- `run.py` strips code between `-- ghdl translate_off` / `-- ghdl translate_on`
  pragmas for GHDL/NVC, so guard simulator-specific constructs with those.

## RTL conventions

- VHDL-2008 throughout (`.hdl_checker.config` sets `-2008`).
- Files follow the banner-comment skeleton in `templates/entity.vhd`: Libraries
  → Entity → Signals → Port mappings → Asynchronous assignments → Processes,
  each under a `-- ... --` banner.
- Shared helpers live in `src/common_pkg.vhd` (`numbits`, `min`/`max`/`sum`,
  `mirror_bits`/`mirror_bytes`, gray<->bin, one-hot conversions,
  `has_undefined`, …) and AXI-Stream record/type definitions in
  `src/axi_pkg.vhd` (`axi_stream_data_bus_t`, etc.). Reuse these rather than
  re-rolling.
- AXI-Stream ports use the standard `s_t*` (slave/input) and `m_t*`
  (master/output) naming. Instantiate sub-blocks with direct entity
  instantiation (`entity work.<name>`).
