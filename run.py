#!/usr/bin/env python
'IGMP reply unit test runner'

from os.path import join, dirname
from vunit import VUnit

def main():
    ui = VUnit.from_argv()
    ui.add_osvvm()
    ui.enable_location_preprocessing()
    #  ui.add_com()
    ui.disable_ieee_warnings()

    root = dirname(__file__)

    for library_name in ('common_lib', 'memory'):
        ui.add_library(library_name).add_source_files(
            join(root, library_name, 'src', '*.vhd'))

    ui.add_library('str_format').add_source_files(
        join(root, 'hdl_string_format', 'src', '*.vhd'))

    ui.add_library('memory_tb').add_source_files(
        join(root, 'memory', 'test', 'async_fifo_tb.vhd'))

    ui.add_library('exp_golomb').add_source_files(
        join(root, 'exponential_golomb', 'src', '*.vhd'))

    #  ui.add_library('exp_golomb_tb').add_source_files(
    #      join(root, 'exponential_golomb', 'test', '*.vhd'))

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
                'WR_CLK_PERIOD' : '%dns' % wr_clk_period,
                'RD_CLK_PERIOD' : '%dns' % rd_clk_period,
                'WR_EN_RANDOM'  : wr_rand,
                'RD_EN_RANDOM'  : rd_rand}
            name = '(wr_period=%dns,rd_clk_period=%dns,wr_rand=%d,rd_rand=%d)' % \
                    (wr_clk_period, rd_clk_period, wr_rand, rd_rand)
            entity.add_config(name=name, generics=generics)


            wr_rand = 3
            rd_rand = 0
            generics = {
                'WR_CLK_PERIOD' : '%dns' % wr_clk_period,
                'RD_CLK_PERIOD' : '%dns' % rd_clk_period,
                'WR_EN_RANDOM'  : wr_rand,
                'RD_EN_RANDOM'  : rd_rand}
            name = '(wr_period=%dns,rd_clk_period=%dns,wr_rand=%d,rd_rand=%d)' % \
                    (wr_clk_period, rd_clk_period, wr_rand, rd_rand)
            entity.add_config(name=name, generics=generics)


            wr_rand = 0
            rd_rand = 3
            generics = {
                'WR_CLK_PERIOD' : '%dns' % wr_clk_period,
                'RD_CLK_PERIOD' : '%dns' % rd_clk_period,
                'WR_EN_RANDOM'  : wr_rand,
                'RD_EN_RANDOM'  : rd_rand}
            name = '(wr_period=%dns,rd_clk_period=%dns,wr_rand=%d,rd_rand=%d)' % \
                    (wr_clk_period, rd_clk_period, wr_rand, rd_rand)
            entity.add_config(name=name, generics=generics)


            wr_rand = 5
            rd_rand = 5
            generics = {
                'WR_CLK_PERIOD' : '%dns' % wr_clk_period,
                'RD_CLK_PERIOD' : '%dns' % rd_clk_period,
                'WR_EN_RANDOM'  : wr_rand,
                'RD_EN_RANDOM'  : rd_rand}
            name = '(wr_period=%dns,rd_clk_period=%dns,wr_rand=%d,rd_rand=%d)' % \
                    (wr_clk_period, rd_clk_period, wr_rand, rd_rand)
            entity.add_config(name=name, generics=generics)


    #  entity.add_config()

if __name__ == '__main__':
    import sys
    sys.exit(main())

