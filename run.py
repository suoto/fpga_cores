#!/usr/bin/env python3
"HDL Library test runner"

# pylint: disable=bad-continuation
# pylint: disable=missing-docstring

import os.path as p
import random
import struct

from vunit import VUnit  # type: ignore

ROOT = p.abspath(p.dirname(__file__))


def main():
    cli = VUnit.from_argv()
    cli.add_osvvm()
    cli.enable_location_preprocessing()
    cli.add_com()

    cli.add_library("fpga_cores").add_source_files(p.join(ROOT, "src", "*.vhd"))

    cli.add_library("str_format").add_source_files(
        p.join(ROOT, "dependencies", "hdl_string_format", "src", "*.vhd")
    )

    cli.add_library("tb")
    cli.library("tb").add_source_files(p.join(ROOT, "testbench", "*.vhd"))

    cli.add_library("fpga_cores_sim")
    cli.library("fpga_cores_sim").add_source_files(p.join(ROOT, "sim", "*.vhd"))

    cli.add_library("exp_golomb").add_source_files(
        p.join(ROOT, "src", "exponential_golomb", "*.vhd")
    )

    addTests(cli)

    cli.set_compile_option("modelsim.vcom_flags", ["-explicit"])

    # Not all options are supported by all GHDL backends
    #  cli.set_compile_option("ghdl.flags", ["-frelaxed-rules"])
    #  cli.set_compile_option("ghdl.flags", ["-frelaxed-rules", "-O0", "-g"])
    cli.set_compile_option("ghdl.flags", ["-frelaxed-rules", "-O2", "-g"])

    # Make components not bound (error 3473) an error
    cli.set_sim_option("modelsim.vsim_flags", ["-error", "3473", '-voptargs="+acc=n"'])
    #  cli.set_sim_option("ghdl.sim_flags", ["-frelaxed-rules"])
    #  cli.set_sim_option("ghdl.elab_e", ["-frelaxed-rules"])
    cli.set_sim_option("ghdl.elab_flags", ["-frelaxed-rules"])

    cli.set_sim_option("disable_ieee_warnings", True)
    cli.set_sim_option("modelsim.init_file.gui", p.join(ROOT, "wave.do"))
    cli.main()


def addTests(cli):
    addAsyncFifoTests(cli.library("tb").entity("async_fifo_tb"))
    addAxiStreamDelayTests(cli.library("tb").entity("axi_stream_delay_tb"))
    addAxiFileReaderTests(cli.library("tb").entity("axi_file_reader_tb"))
    addAxiFileCompareTests(cli.library("tb").entity("axi_file_compare_tb"))
    addAxiWidthConverterTests(cli.library("tb").entity("axi_stream_width_converter_tb"))


def addAsyncFifoTests(entity):
    clk_period_list = (4, 11)

    for wr_clk_period in clk_period_list:
        for rd_clk_period in clk_period_list:
            for wr_rand, rd_rand in (
                (0, 0),
                (3, 0),
                (0, 3),
                (5, 5),
            ):
                name = ",".join(
                    [
                        f"wr_clk_period={wr_clk_period}",
                        f"rd_clk_period={rd_clk_period}",
                        f"wr_rand={wr_rand}",
                        f"rd_rand={rd_rand}",
                    ]
                )

                entity.add_config(
                    name=name,
                    generics=dict(
                        WR_CLK_PERIOD_NS=wr_clk_period,
                        RD_CLK_PERIOD_NS=rd_clk_period,
                        WR_EN_RANDOM=wr_rand,
                        RD_EN_RANDOM=rd_rand,
                    ),
                )


def addAxiStreamDelayTests(entity):
    "Parametrizes the delays for the AXI stream delay test"
    for delay in (1, 2, 8):
        entity.add_config(name=f"delay={delay}", generics={"DELAY_CYCLES": delay})


def addAxiFileCompareTests(entity):
    "Parametrizes the AXI file compare testbench"
    test_file = p.join(ROOT, "vunit_out", "file_compare_input.bin")
    reference_file = p.join(ROOT, "vunit_out", "file_compare_reference_ok.bin")

    if not (p.exists(test_file) and p.exists(reference_file)):
        generateAxiFileReaderTestFile(
            test_file=test_file,
            reference_file=reference_file,
            data_width=32,
            length=256 * 32,
            ratio=(32, 32),
        )

    tdata_single_error_file = p.join(
        ROOT, "vunit_out", "file_compare_reference_tdata_1_error.bin"
    )
    tdata_two_errors_file = p.join(
        ROOT, "vunit_out", "file_compare_reference_tdata_2_errors.bin"
    )

    if not p.exists(tdata_single_error_file):
        ref_data = open(reference_file, "rb").read().split(b"\n")

        with open(tdata_single_error_file, "wb") as fd:
            # Skip one, duplicate another so the size is the same
            data = ref_data[:7] + [ref_data[8],] + ref_data[8:]
            fd.write(b"\n".join(data))

    if not p.exists(tdata_two_errors_file):
        ref_data = open(reference_file, "rb").read().split(b"\n")

        with open(tdata_two_errors_file, "wb") as fd:
            # Skip one, duplicate another so the size is the same
            data = (
                ref_data[:7]
                + [ref_data[8], ref_data[8]]
                + ref_data[9:16]
                + [ref_data[17],]
                + ref_data[17:]
            )
            fd.write(b"\n".join(data))

    entity.add_config(
        name="all",
        generics=dict(
            input_file=test_file,
            reference_file=reference_file,
            tdata_single_error_file=tdata_single_error_file,
            tdata_two_errors_file=tdata_two_errors_file,
        ),
    )


def addAxiFileReaderTests(entity):
    "Parametrizes the AXI file reader testbench"
    for data_width in (1, 8, 32):
        all_configs = []

        for ratio in (
            (1, 8),
            (2, 8),
            (3, 8),
            (5, 8),
            (7, 8),
            (8, 8),
            (1, 4),
            (2, 4),
            (1, 1),
            (8, 32),
        ):

            basename = (
                f"file_reader_data_width_{data_width}_ratio_{ratio[0]}_{ratio[1]}"
            )

            test_file = p.join(ROOT, "vunit_out", basename + "_input.bin")
            reference_file = p.join(ROOT, "vunit_out", basename + "_reference.bin")

            if not (p.exists(test_file) and p.exists(reference_file)):
                generateAxiFileReaderTestFile(
                    test_file=test_file,
                    reference_file=reference_file,
                    data_width=data_width,
                    length=256 * data_width,
                    ratio=ratio,
                )

            test_cfg = ",".join([f"{ratio[0]}:{ratio[1]}", test_file, reference_file])

            all_configs += [test_cfg]

            # Uncomment this to test configs individually
            #  name = f"single,data_width={data_width},ratio={ratio[0]}:{ratio[1]}"
            #  entity.add_config(
            #      name=name, generics={"DATA_WIDTH": data_width, "test_cfg": test_cfg}
            #  )

        entity.add_config(
            name=f"multiple,data_width={data_width}",
            generics={"DATA_WIDTH": data_width, "test_cfg": "|".join(all_configs)},
        )


def swapBits(value, width=8):
    "Swaps LSB and MSB bits of <value>, considering its width is <width>"
    v_in_binary = bin(value)[2:]

    assert len(v_in_binary) <= width, "input is too big"

    v_in_binary = "0" * (width - len(v_in_binary)) + v_in_binary
    return int(v_in_binary[::-1], 2)


def generateAxiFileReaderTestFile(test_file, reference_file, data_width, length, ratio):
    "Create a pair of test files for the AXI file reader testbench"
    rand_max = 2 ** data_width
    ratio_first, ratio_second = ratio
    packed_data = []
    unpacked_bytes = []

    buffer_length = 0
    buffer_data = 0
    byte = ""

    for _ in range(length):
        for ratio_i in reversed(range(ratio_second)):
            if ratio_i < ratio_first:
                # Generate a new data word every time the previous is read out
                # completely
                if buffer_length == 0:
                    buffer_data = random.randrange(0, rand_max)
                    packed_data += [buffer_data]

                    buffer_data = swapBits(buffer_data, width=data_width)
                    buffer_length += data_width

                byte += str(buffer_data & 1)

                buffer_data >>= 1
                buffer_length -= 1
            else:
                # Pad only
                byte += "0"

            # Every time we get enough data, save it and reset it
            if len(byte) == 8:
                unpacked_bytes += [int(byte, 2)]
                byte = ""

    assert not byte, (
        f"Data width {data_width}, length {length} is invalid, "
        "need to make sure data_width*length is divisible by 8"
    )

    with open(test_file, "wb") as fd:
        for byte in unpacked_bytes:
            fd.write(struct.pack(">B", byte))

    # Format will depend on the data width, need to be wide enough for to fit
    # one character per nibble
    fmt = "%.{}x\n".format((data_width + 3) // 4)
    with open(reference_file, "w") as fd:
        for word in packed_data:
            fd.write(fmt % word)

    return packed_data


def addAxiWidthConverterTests(entity):
    # Only add equal widths once
    entity.add_config(
        name="same_widths", generics=dict(INPUT_DATA_WIDTH=32, OUTPUT_DATA_WIDTH=32,),
    )

    for input_data_width in {1, 8, 24, 32, 128}:
        for output_data_width in {1, 8, 24, 32, 128} - {input_data_width}:
            if output_data_width >= input_data_width:
                continue
            entity.add_config(
                name=f"input_data_width={input_data_width},"
                + f"output_data_width={output_data_width}",
                generics=dict(
                    INPUT_DATA_WIDTH=input_data_width,
                    OUTPUT_DATA_WIDTH=output_data_width,
                ),
            )


if __name__ == "__main__":
    import sys

    sys.exit(main())
