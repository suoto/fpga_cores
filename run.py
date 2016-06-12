#!/usr/bin/env python
'IGMP reply unit test runner'

from os.path import join, dirname
from vunit import VUnit

def main():
    ui = VUnit.from_argv()
    ui.add_osvvm()
    ui.disable_ieee_warnings()

    src_path = join(dirname(__file__), 'src')

    pck_fio_lib = ui.add_library('pck_fio_lib')
    pck_fio_lib.add_source_files('pck_fio_lib/src/*.vhd')

    for library_name in ('common_lib', 'memory'):
        library = ui.add_library(library_name)
        library.add_source_files(library_name + '/*.vhd')

    memory_tb = ui.add_library('memory_tb')
    memory_tb.add_source_files('./memory/testbench/*.vhd')

    add_async_fifo_tests(ui.library('memory_tb').entity('async_fifo_tb'))

    ui.set_compile_option('modelsim.vcom_flags', ['-novopt', '-explicit'])
    ui.set_sim_option('modelsim.vsim_flags', ['-novopt'])
    ui.main()

def add_async_fifo_tests(entity):
    clk_period_list = (4, 11)

    for wr_clk_period in clk_period_list:
        for rd_clk_period in clk_period_list:
            wr_rand = 0
            rd_rand = 0
            generics = {
                'WR_CLK_PERIOD' : '%d ns' % wr_clk_period,
                'RD_CLK_PERIOD' : '%d ns' % rd_clk_period,
                'WR_EN_RANDOM'  : wr_rand,
                'RD_EN_RANDOM'  : rd_rand}
            name = '(wr_period=%d,rd_clk_period=%d,wr_rand=%d,rd_rand=%d)' % \
                    (wr_clk_period, rd_clk_period, wr_rand, rd_rand)
            entity.add_config(name=name, generics=generics)


            wr_rand = 3
            rd_rand = 0
            generics = {
                'WR_CLK_PERIOD' : '%d ns' % wr_clk_period,
                'RD_CLK_PERIOD' : '%d ns' % rd_clk_period,
                'WR_EN_RANDOM'  : wr_rand,
                'RD_EN_RANDOM'  : rd_rand}
            name = '(wr_period=%d,rd_clk_period=%d,wr_rand=%d,rd_rand=%d)' % \
                    (wr_clk_period, rd_clk_period, wr_rand, rd_rand)
            entity.add_config(name=name, generics=generics)


            wr_rand = 0
            rd_rand = 3
            generics = {
                'WR_CLK_PERIOD' : '%d ns' % wr_clk_period,
                'RD_CLK_PERIOD' : '%d ns' % rd_clk_period,
                'WR_EN_RANDOM'  : wr_rand,
                'RD_EN_RANDOM'  : rd_rand}
            name = '(wr_period=%d,rd_clk_period=%d,wr_rand=%d,rd_rand=%d)' % \
                    (wr_clk_period, rd_clk_period, wr_rand, rd_rand)
            entity.add_config(name=name, generics=generics)


            wr_rand = 5
            rd_rand = 5
            generics = {
                'WR_CLK_PERIOD' : '%d ns' % wr_clk_period,
                'RD_CLK_PERIOD' : '%d ns' % rd_clk_period,
                'WR_EN_RANDOM'  : wr_rand,
                'RD_EN_RANDOM'  : rd_rand}
            name = '(wr_period=%d,rd_clk_period=%d,wr_rand=%d,rd_rand=%d)' % \
                    (wr_clk_period, rd_clk_period, wr_rand, rd_rand)
            entity.add_config(name=name, generics=generics)


    #  entity.add_config()

if __name__ == '__main__':
    import sys
    sys.exit(main())

