#!/usr/bin/env python

import sys
import os.path as p
from vunit import VUnit

def main():
    root = p.dirname(__file__)

    ui = VUnit.from_argv()

    #  pylint: disable=bad-whitespace
    for lib_name, lib_flags in (
            ('memory',       []),
            ('common_lib',   []),
            ('osvvm_lib',    ['-2008']),):
        lib = ui.add_library(lib_name)
        lib.add_source_files(p.join(root, lib_name, "*.vhd"))
        lib.add_compile_option('modelsim.vcom_flags', lib_flags)
    #  pylint: enable=bad-whitespace
    lib = ui.add_library('tb')
    lib.add_source_files(p.join(root, 'memory/testbench/*.vhd'))

    ui.main()

if __name__ == '__main__':
    sys.exit(main())
