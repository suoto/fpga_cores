#!/usr/bin/env python
"Golomb library unit test runner"

from os.path import join, dirname
from vunit import VUnit

def main():
    ui = VUnit.from_argv()
    ui.add_osvvm()

    src_path = join(dirname(__file__), "src")

    exp_golomb_lib = ui.add_library("exp_golomb_lib")
    exp_golomb_lib.add_source_files(join(src_path, "*.vhd"))

    exp_golomb_tb = ui.add_library("exp_golomb_tb_lib")
    exp_golomb_tb.add_source_files(join(src_path, "test", "*.vhd"))

    ui.set_compile_option('modelsim.vcom_flags', ['-novopt', '-explicit'])
    ui.set_sim_option('modelsim.vsim_flags', ['-novopt'])
    ui.main()

import sys
sys.exit(main())
