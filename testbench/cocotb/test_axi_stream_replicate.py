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
# As per CERN-OHL-W v2 section 4.1, should You produce hardware based on these
# sources, You must maintain the Source Location visible on the external case
# of the FPGA Cores or other product you make using this documentation.

"""
cocotb testbench for axi_stream_replicate (SystemVerilog).

Port of testbench/axi_stream_replicate_tb.vhd. The DUT fans a single input
stream (s_*) out to INTERFACES output interfaces (m_*), each with independent
tready backpressure. Every interface must receive the same word sequence.

The input is driven with cocotbext-axi's AxiStreamSource. The outputs are packed
vectors (m_tvalid[INTERFACES], m_tready[INTERFACES],
m_tdata[INTERFACES][TDATA_WIDTH]) rather than one bus per interface, so instead
of AxiStreamSink we hand-roll a per-interface ready randomizer (mirrors the VHDL
rd_en_randomize) and a passive monitor that samples the packed vectors and
compares each interface's accepted stream against the expected words.
"""

import os
import random
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ReadOnly, RisingEdge
from cocotb_tools.runner import get_runner
from cocotbext.axi import AxiStreamBus, AxiStreamSource

INTERFACES = 4
TDATA_WIDTH = 8
CLK_PERIOD_NS = 5  # matches CLK_PERIOD = 5 ns in the VHDL TB


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.log = dut._log

        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit="ns").start())

        self.source = AxiStreamSource(
            AxiStreamBus.from_prefix(dut, "s"),
            dut.clk,
            dut.rst,
            reset_active_level=True,
        )

    async def reset(self):
        # rst held high 16 cycles, low 16 cycles -- same as walk(16) in the TB
        self.dut.m_tready.value = 0
        self.dut.rst.value = 1
        for _ in range(16):
            await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        for _ in range(16):
            await RisingEdge(self.dut.clk)

    @staticmethod
    def _bit(sig, i):
        """Bit `i` of a packed [WIDTH-1:0] vector (index 0 = LSB); x/z -> 0."""
        s = str(sig.value)  # MSB-first logic string, e.g. "1010"
        return 1 if s[len(s) - 1 - i] == "1" else 0

    def _iface_data(self, i):
        """Word for interface `i` from the packed [INTERFACES][TDATA_WIDTH] bus."""
        s = str(self.dut.m_tdata.value)  # MSB-first; interface 0 in the LSBs
        hi = len(s) - i * TDATA_WIDTH
        lo = hi - TDATA_WIDTH
        return int(s[lo:hi], 2)

    async def ready_driver(self, probabilities, rng):
        """Randomize m_tready per interface every cycle (mirrors rd_en_randomize)."""
        # Packed ports can't be indexed in cocotb 2.x, so drive the whole vector.
        self.dut.m_tready.value = 0
        while True:
            await RisingEdge(self.dut.clk)
            value = 0
            for i, prob in enumerate(probabilities):
                if rng.random() < prob:
                    value |= 1 << i
            self.dut.m_tready.value = value

    async def monitor(self, i, expected):
        """Check every accepted beat on interface `i` against `expected`, in order."""
        got = []
        while len(got) < len(expected):
            await RisingEdge(self.dut.clk)
            await ReadOnly()
            if self._bit(self.dut.m_tvalid, i) and self._bit(self.dut.m_tready, i):
                got.append(self._iface_data(i))
        assert got == expected, (
            f"interface {i} data mismatch:\n"
            f"  expected={expected}\n  got     ={got}"
        )


async def run_test(dut, words, probabilities, wait_before_ready=True):
    tb = TB(dut)
    rng = random.Random(int(os.environ.get("COCOTB_RANDOM_SEED", 0)) ^ words)

    await tb.reset()

    data = [rng.randint(0, (1 << TDATA_WIDTH) - 1) for _ in range(words)]

    # test_tvalid_before_tready skips the walk(1) so ready randomization and data
    # start together; otherwise the ready driver settles for a cycle first.
    ready = cocotb.start_soon(tb.ready_driver(probabilities, rng))
    if wait_before_ready:
        await RisingEdge(dut.clk)

    monitors = [cocotb.start_soon(tb.monitor(i, list(data))) for i in range(INTERFACES)]

    await tb.source.send(bytes(data))
    for mon in monitors:
        await mon

    ready.kill()
    dut._log.info("Done")


@cocotb.test(timeout_time=1, timeout_unit="ms")
async def test_all_ready(dut):
    await run_test(dut, words=16, probabilities=[1.0] * INTERFACES)


@cocotb.test(timeout_time=1, timeout_unit="ms")
async def test_1_slow_interface(dut):
    await run_test(dut, words=16, probabilities=[1.0, 1.0, 1.0, 0.5])


@cocotb.test(timeout_time=1, timeout_unit="ms")
async def test_2_slow_interfaces(dut):
    await run_test(dut, words=16, probabilities=[1.0, 1.0, 0.9, 0.8])


@cocotb.test(timeout_time=1, timeout_unit="ms")
async def test_all_slow_interfaces(dut):
    await run_test(dut, words=256, probabilities=[0.9] * INTERFACES)


@cocotb.test(timeout_time=1, timeout_unit="ms")
async def test_tvalid_before_tready(dut):
    await run_test(
        dut, words=256, probabilities=[0.9] * INTERFACES, wait_before_ready=False
    )


# ---------------------------------------------------------------------------
# pytest entry point: build + run with the cocotb runner (Icarus)
# ---------------------------------------------------------------------------


def test_axi_stream_replicate():
    src = Path(__file__).resolve().parents[2] / "src"

    # Dump waves when WAVES=1 -> build_dir/axi_stream_replicate.fst
    waves = os.environ.get("WAVES", "0") == "1"

    runner = get_runner("icarus")
    runner.build(
        sources=[src / "axi_stream_replicate.sv"],
        hdl_toplevel="axi_stream_replicate",
        parameters={"INTERFACES": INTERFACES, "TDATA_WIDTH": TDATA_WIDTH},
        build_args=["-g2012"],
        build_dir="sim_build/axi_stream_replicate",
        always=True,
        waves=waves,
    )
    runner.test(
        hdl_toplevel="axi_stream_replicate",
        test_module="test_axi_stream_replicate",
        waves=waves,
    )
