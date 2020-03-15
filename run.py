#!/usr/bin/env python3
"HDL Library test runner"

import os.path as p

from vunit import VUnit  # type: ignore


def main():
    cli = VUnit.from_argv()
    cli.add_osvvm()
    cli.enable_location_preprocessing()
    #  cli.add_com()

    root = p.dirname(__file__)

    cli.add_library("rtl").add_source_files(p.join(root, "src", "*.vhd"))

    cli.add_library("str_format").add_source_files(
        p.join(root, "dependencies", "hdl_string_format", "src", "*.vhd")
    )

    cli.add_library("sim").add_source_files(p.join(root, "test", "*.vhd"))

    cli.add_library("exp_golomb").add_source_files(
        p.join(root, "src", "exponential_golomb", "src", "*.vhd")
    )

    cli.add_library('exp_golomb_tb').add_source_files(
        p.join(root, "src", 'exponential_golomb', 'test', '*.vhd'))

    add_async_fifo_tests(cli.library("sim").entity("async_fifo_tb"))

    cli.set_compile_option("modelsim.vcom_flags", ["-explicit"])

    # Not all options are supported by all GHDL backends
    #  cli.set_compile_option("ghdl.flags", ["-frelaxed-rules"])
    #  cli.set_compile_option("ghdl.flags", ["-frelaxed-rules", "-O0", "-g"])
    cli.set_compile_option("ghdl.a_flags", ["-frelaxed-rules", "-O2", "-g"])

    # Make components not bound (error 3473) an error
    cli.set_sim_option("modelsim.vsim_flags", ["-error", "3473", '-voptargs="+acc=n"'])
    #  cli.set_sim_option("ghdl.sim_flags", ["-frelaxed-rules"])
    #  cli.set_sim_option("ghdl.elab_e", ["-frelaxed-rules"])
    #  cli.set_sim_option("ghdl.elab_flags", ["-frelaxed-rules"])

    cli.set_sim_option("disable_ieee_warnings", True)
    cli.set_sim_option("modelsim.init_file.gui", p.join(root, "wave.do"))
    cli.main()


def add_async_fifo_tests(entity):
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


if __name__ == "__main__":
    import sys

    sys.exit(main())
