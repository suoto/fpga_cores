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
cocotb testbench for axi_stream_delay (SystemVerilog).

Port of testbench/axi_stream_delay_tb.vhd. Drives the DUT with cocotbext-axi's
AxiStreamSource/Sink; backpressure (slow master/slave) is modelled with pause
generators. The DUT has no tlast/tkeep, so the scoreboard compares the flat byte
stream via a passive monitor rather than AxiStreamSink.recv() (which would block
forever waiting for a frame boundary that never comes).
"""

import os
import random
from pathlib import Path

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb_tools.runner import get_runner
from cocotbext.axi import AxiStreamBus, AxiStreamSink, AxiStreamSource

TDATA_WIDTH = 8
CLK_PERIOD_NS = 5  # matches CLK_PERIOD = 5 ns in the VHDL TB


def pause_generator(rng, active_probability):
    """Yields True on cycles where the interface should stall.

    `active_probability` mirrors the VHDL tvalid/tready_probability: the fraction
    of cycles the interface is *active*, so a cycle is paused with probability
    1 - active_probability.
    """
    while True:
        yield rng.random() >= active_probability


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
        self.sink = AxiStreamSink(
            AxiStreamBus.from_prefix(dut, "m"),
            dut.clk,
            dut.rst,
            reset_active_level=True,
        )

    async def reset(self):
        # rst held high 8 cycles, low 8 cycles -- same as walk(8)/rst<='0'/walk(8)
        self.dut.rst.value = 1
        for _ in range(8):
            await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        for _ in range(8):
            await RisingEdge(self.dut.clk)

    async def monitor(self, expected):
        """Passively check every accepted m_* beat against `expected`, in order."""
        got = []
        while len(got) < len(expected):
            await RisingEdge(self.dut.clk)
            if self.dut.m_tvalid.value == 1 and self.dut.m_tready.value == 1:
                got.append(int(self.dut.m_tdata.value))
        assert got == expected, (
            f"data mismatch:\n  expected={expected}\n  got     ={got}"
        )


async def run_test(dut, n, tvalid_probability, tready_probability):
    tb = TB(dut)
    # cocotb seeds `random` from COCOTB_RANDOM_SEED; derive a local, reproducible
    # RNG from it so the stimulus for a given seed is stable.
    rng = random.Random(int(os.environ.get("COCOTB_RANDOM_SEED", 0)) ^ n)

    await tb.reset()

    if tvalid_probability < 1.0:
        tb.source.set_pause_generator(pause_generator(rng, tvalid_probability))
    if tready_probability < 1.0:
        tb.sink.set_pause_generator(pause_generator(rng, tready_probability))

    data = [rng.randint(0, (1 << TDATA_WIDTH) - 1) for _ in range(n)]

    checker = cocotb.start_soon(tb.monitor(list(data)))
    await tb.source.send(bytes(data))
    await checker

    dut._log.info("Done")


@cocotb.test(timeout_time=1, timeout_unit="ms")
async def single_word(dut):
    await run_test(dut, n=1, tvalid_probability=1.0, tready_probability=1.0)


@cocotb.test(timeout_time=1, timeout_unit="ms")
async def back_to_back_frame(dut):
    await run_test(dut, n=16, tvalid_probability=1.0, tready_probability=1.0)


@cocotb.test(timeout_time=1, timeout_unit="ms")
async def slow_slave(dut):
    await run_test(dut, n=16, tvalid_probability=1.0, tready_probability=0.20)


@cocotb.test(timeout_time=1, timeout_unit="ms")
async def slow_master(dut):
    await run_test(dut, n=16, tvalid_probability=0.20, tready_probability=1.0)


@cocotb.test(timeout_time=1, timeout_unit="ms")
async def slow_master_and_slave(dut):
    await run_test(dut, n=16, tvalid_probability=0.50, tready_probability=0.50)


# ---------------------------------------------------------------------------
# pytest entry point: build + run with the cocotb runner (Icarus)
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("delay_cycles", [0, 1, 2, 8])  # 0 = combinational passthrough
def test_axi_stream_delay(delay_cycles):
    # # Make this file importable as the cocotb test module from the sim build dir
    # os.environ["PYTHONPATH"] = (
    #     str(Path(__file__).parent) + os.pathsep + os.environ.get("PYTHONPATH", "")
    # )

    src = Path(__file__).resolve().parents[2] / "src"

    # Dump waves when WAVES=1 -> build_dir/axi_stream_delay.fst
    waves = os.environ.get("WAVES", "0") == "1"

    runner = get_runner("icarus")
    runner.build(
        sources=[
            src / "axi_stream_forward_slice.sv",
            src / "axi_stream_delay.sv",
        ],
        hdl_toplevel="axi_stream_delay",
        parameters={"TDATA_WIDTH": TDATA_WIDTH, "DELAY_CYCLES": delay_cycles},
        build_args=["-g2012"],
        build_dir=f"sim_build/delay_{delay_cycles}",
        always=True,
        waves=waves,
    )
    runner.test(
        hdl_toplevel="axi_stream_delay",
        test_module="test_axi_stream_delay",
        waves=waves,
    )
