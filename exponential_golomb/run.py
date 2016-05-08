#!/usr/bin/env python
"Golomb library unit test runner"

# This file is part of hdl_lib
#
# hdl_lib is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# hdl_lib is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# In addition to the GNU General Public License terms and conditions,
# under the section 7 - Additional Terms, include the following:
#    g) All files of this work contain lines identifying the original
#    author and release date. This line SHOULD NOT be removed or
#    changed for any reason unless explicitly allowed by the author in
#    the form of writing. Note that this seeks to prevent this work
#    from being misused. Misuse includes but doesn't limits to code
#    evaluation of candidates from employers. All remaining GNU
#    General Public License terms still apply.
#
# You should have received a copy of the GNU General Public License
# along with hdl_lib.  If not, see <http://www.gnu.org/licenses/>.
#
# Author: Andre Souto (github.com/suoto) [DO NOT REMOVE]
# Date: 2016/04/18 [DO NOT REMOVE]

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

