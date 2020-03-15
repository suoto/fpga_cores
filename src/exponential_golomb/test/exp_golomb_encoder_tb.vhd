--
-- hdl_lib -- A(nother) HDL library
--
-- Copyright 2014-2016 by Andre Souto (suoto)
--
-- This file is part of hdl_lib.
-- 
-- hdl_lib is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
-- 
-- In addition to the GNU General Public License terms and conditions,
-- under the section 7 - Additional Terms, include the following:
--    g) All files of this work contain lines identifying the original
--    author and release date. This line SHOULD NOT be removed or
--    changed for any reason unless explicitly allowed by the author in
--    the form of writing. Note that this seeks to prevent this work
--    from being misused. Misuse includes but doesn't limits to code
--    evaluation of candidates from employers. All remaining GNU
--    General Public License terms still apply.
--
-- hdl_lib is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
-- You should have received a copy of the GNU General Public License
-- along with hdl_lib.  If not, see <http://www.gnu.org/licenses/>.
--
-- Author: Andre Souto (github.com/suoto) [DO NOT REMOVE]
-- Date: 2016/04/18 [DO NOT REMOVE]
---------------
-- Libraries --
---------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;

library exp_golomb_tb;

library exp_golomb;
    use exp_golomb.exp_golomb_pkg;

------------------------
-- Entity declaration --
------------------------
entity exp_golomb_encoder_tb is
    generic (runner_cfg : string);
end entity;

architecture tb of exp_golomb_encoder_tb is

    ---------------
    -- Constants --
    ---------------
    constant CLK_PERIOD : time    := 10 ns;
    constant DATA_WIDTH : integer := 32;

    -------------
    -- Signals --
    -------------
    signal clk : std_logic := '1';
    signal rst : std_logic;

    -- Data input
    signal axi_in_tdata   : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal axi_in_tvalid  : std_logic := '0';
    signal axi_in_tready  : std_logic;

    -- Data output
    signal axi_out_tdata   : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal axi_out_tvalid  : std_logic;
    signal axi_out_tready  : std_logic := '1';

begin
    -------------------
    -- Port mappings --
    -------------------
    dut : entity exp_golomb.exp_golomb_encoder
        generic map (
            DATA_WIDTH   => DATA_WIDTH)
        port map (
            clk            => clk,
            clken          => '1',
            rst            => rst,

            -- Data input
            axi_in_tdata   => axi_in_tdata,
            axi_in_tvalid  => axi_in_tvalid,
            axi_in_tready  => axi_in_tready,

            -- Data output
            axi_out_tdata  => axi_out_tdata,
            axi_out_tvalid => axi_out_tvalid,
            axi_out_tready => axi_out_tready);

    -- file_dump_u : entity exp_golomb_tb.file_dumper
    --     generic map (
    --         FILENAME   => "output.bin",
    --         DATA_WIDTH => DATA_WIDTH)
    --     port map (
    --         clk     => clk,
    --         clken   => '1',
    --         rst     => rst,

    --         -- Data input
    --         tdata   => axi_out_tdata,
    --         tvalid  => axi_out_tvalid,
    --         tready  => axi_out_tready);

    -----------------------------
    -- Asynchronous assignments --
    -----------------------------
    clk <= not clk after CLK_PERIOD/2;
    rst <= '1', '0' after 16*CLK_PERIOD;

    main : process
        procedure write_data (data : in std_logic_vector) is
            begin
                axi_in_tvalid <= '1';
                axi_in_tdata  <= data;
                wait until axi_in_tvalid = '1' and 
                           axi_in_tready = '1' and 
                           rising_edge(clk);
                axi_in_tvalid <= '0';
                axi_in_tdata <= (others => 'X');
            end procedure;
        procedure write_data (data : in integer) is
            begin
                write_data(std_logic_vector(to_unsigned(data, DATA_WIDTH)));
            end procedure;


        procedure test_bin_width is
            variable data             : unsigned(DATA_WIDTH - 1 downto 0);
            variable bin_width_result : integer;
        begin

            for i in 0 to 8 loop
                data := to_unsigned(i, DATA_WIDTH);
                bin_width_result := exp_golomb.exp_golomb_pkg.bin_width(data);
                check_equal(
                    bin_width_result,
                    exp_golomb.exp_golomb_pkg.numbits(i));
                end loop;

            data := to_unsigned(32, DATA_WIDTH);
            bin_width_result := exp_golomb.exp_golomb_pkg.bin_width(data);
            check_equal(
                bin_width_result,
                exp_golomb.exp_golomb_pkg.numbits(32));

            for i in 29 downto 2 loop
                for offset in -2 to 2 loop
                    data := to_unsigned(2**i + offset, DATA_WIDTH);
                    bin_width_result := exp_golomb.exp_golomb_pkg.bin_width(data);
                    check_equal(
                        bin_width_result,
                        exp_golomb.exp_golomb_pkg.numbits(2**i + offset));
                end loop;
            end loop;

        end procedure;


        procedure test_stream_data is
        begin
            for i in 0 to 2**15 - 1 loop
                write_data(i);
            end loop;
        end procedure;

        procedure test_data_limits is
        begin
            for i in 0 to 1023 loop
                write_data(2**16 - 1);
                -- (DATA_WIDTH - 1 downto DATA_WIDTH/2 => '0',
                --             DATA_WIDTH/2 - 1 downto 0          => '1'));
            end loop;

            -- for i in 2**19 downto 0 loop
            --     write_data(i);
            -- end loop;

        end procedure;

        variable stat   : checker_stat_t;

    begin
        test_runner_setup(runner, runner_cfg);

        -- -- Initialize to same seed to get same sequence
        -- rnd_stimuli.InitSeed(rnd_stimuli'instance_name);
        -- rnd_expected.InitSeed(rnd_stimuli'instance_name);

        wait until rst = '0';

        while test_suite loop
            if run("test_bin_width") then
                test_bin_width;
            elsif run("test_stream_data") then
                test_stream_data;
            elsif run("test_data_limits") then
                test_data_limits;
            end if;
        end loop;

        if not active_python_runner(runner_cfg) then
            get_checker_stat(stat);
            info(LF & "Result:" & LF & to_string(stat));
        end if;

        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 10 ms);

end architecture;

