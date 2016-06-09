-- This file is part of hdl_lib
--
-- hdl_lib is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- hdl_lib is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with hdl_lib.  If not, see <http://www.gnu.org/licenses/>.

-- Author: Andre Souto (github.com/suoto) [DO NOT REMOVE]
-- Date: 2016/04/18 [DO NOT REMOVE]
---------------
-- Libraries --
---------------
use std.textio.all;
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    use vunit_lib.lang.all;
    use vunit_lib.string_ops.all;
    use vunit_lib.dictionary.all;
    use vunit_lib.path.all;
    use vunit_lib.log_types_pkg.all;
    use vunit_lib.log_special_types_pkg.all;
    use vunit_lib.log_pkg.all;
    use vunit_lib.check_types_pkg.all;
    use vunit_lib.check_special_types_pkg.all;
    use vunit_lib.check_pkg.all;
    use vunit_lib.run_types_pkg.all;
    use vunit_lib.run_special_types_pkg.all;
    use vunit_lib.run_base_pkg.all;
    use vunit_lib.run_pkg.all;

library pck_fio_lib;
    use pck_fio_lib.pck_fio.all;

------------------------
-- Entity declaration --
------------------------
entity pck_fio_tb is
    generic (runner_cfg : string);
end entity;

architecture tb of pck_fio_tb is

    ---------------
    -- Constants --
    ---------------

    -------------
    -- Signals --
    -------------

begin
    -------------------
    -- Port mappings --
    -------------------

    -----------------------------
    -- Asynchronous assignments --
    -----------------------------
    test_runner_watchdog(runner, 10 ms);

    ---------------
    -- Processes --
    ---------------
    main : process
        variable stat   : checker_stat_t;
        variable filter : log_filter_t;

        --
        variable L       : line;
        variable pointer : integer := 1;
    -- begin

        -- variable value : std_logic_vector(15 downto 0);
        constant value : std_logic_vector(15 downto 0) := x"1234";
        constant COLOR_BOLD  : string := esc & "[1;34m";
        constant COLOR_RESET : string := esc & "[0m";

        impure function colorize (
            constant attributes : string) return string is
            variable lines      : lines_t := split(attributes, " ");
            constant attr_cnt   : integer := lines'length;
            variable attr       : line;
        begin
            for i in 0 to attr_cnt - 1 loop
                if lines(i).all = "blink"             then write(attr, string'("5"));
                elsif lines(i).all = "bold"           then write(attr, string'("1"));
                elsif lines(i).all = "dim"            then write(attr, string'("2"));
                elsif lines(i).all = "reverse"        then write(attr, string'("7"));
                elsif lines(i).all = "highlight"      then write(attr, string'("7"));
                elsif lines(i).all = "highlight-off"  then write(attr, string'("27"));
                elsif lines(i).all = "underline"      then write(attr, string'("4"));
                elsif lines(i).all = "underline-off"  then write(attr, string'("24"));
                elsif lines(i).all = "black"          then write(attr, string'("30"));
                elsif lines(i).all = "red"            then write(attr, string'("31"));
                elsif lines(i).all = "green"          then write(attr, string'("32"));
                elsif lines(i).all = "yellow"         then write(attr, string'("33"));
                elsif lines(i).all = "blue"           then write(attr, string'("34"));
                elsif lines(i).all = "magenta"        then write(attr, string'("35"));
                elsif lines(i).all = "cyan"           then write(attr, string'("36"));
                elsif lines(i).all = "gray"           then write(attr, string'("37"));
                elsif lines(i).all = "bg-black"       then write(attr, string'("40"));
                elsif lines(i).all = "bg-red"         then write(attr, string'("41"));
                elsif lines(i).all = "bg-green"       then write(attr, string'("42"));
                elsif lines(i).all = "bg-yellow"      then write(attr, string'("43"));
                elsif lines(i).all = "bg-blue"        then write(attr, string'("44"));
                elsif lines(i).all = "bg-magenta"     then write(attr, string'("45"));
                elsif lines(i).all = "bg-cyan"        then write(attr, string'("46"));
                elsif lines(i).all = "bg-gray"        then write(attr, string'("47"));
                elsif lines(i).all = "reset"          then write(attr, string'("0"));
                else
                    report "Invalid attribute name " & lines(i).all
                        severity Error;
                end if;

                if i /= attr_cnt - 1 then
                    write(attr, string'(";"));
                else
                    write(attr, string'("m"));
                end if;


            end loop;
            -- info("attributes: " & attr.all);
            return esc & "[" & attr.all;
        end function;

        procedure cinfo(
            constant message : string) is
        begin
            write(output, colorize("green"));
            info(message & colorize("reset"));
            -- write(output, colorize("reset"));
        end procedure;

        procedure cwarn(
            constant message : string) is
        begin
            write(output, colorize("yellow"));
            warning(message & colorize("reset"));
            -- write(output, colorize("reset"));
        end procedure;


    begin
        checker_init(display_format => verbose,
            file_name               => join(output_path(runner_cfg), "error.csv"),
            file_format             => verbose_csv);

        logger_init(display_format => verbose,
            file_name              => join(output_path(runner_cfg), "log.csv"),
            file_format            => verbose_csv);

        stop_level((debug, verbose), display_handler, filter);

        test_runner_setup(runner, runner_cfg);

        -- wait until rst = '0';
  -- procedure FIO_PrintArg (file F:  text;
  --             L:       inout line; 
  --             Format:  in    string; 
  --             Pointer: inout integer;
  --             Arg:     in    string) is

        cinfo("Some cinfo");
        cwarn("Some warning");

        while test_suite loop
            if run("testing") then
                -- value := std_logic_vector(to_unsigned(16#1234#, 16));
                cinfo(sprintf("Reasonable representation           %r", fo(value)));
                info(sprintf("Binary representation               %b", fo(value)));
                cinfo(sprintf("Decimal representation:             %d", fo(value)));
                info(sprintf("String representation               %s", fo(value)));
                cinfo(sprintf("qualified (internal) representation %q", fo(value)));
                -- cinfo("Reasonable representation " & sprintf("%r", fo(value)));
                -- cinfo("Binary representation     " & sprintf("%b", fo(value)));
                -- cinfo("Decimal representation:   " & sprintf("%d", fo(value)));
                -- cinfo("Reasonable representation " & sprintf("%s", fo(value)));
                -- cinfo("Reasonable representation " & sprintf("%q", fo(value)));
               -- -- report "FIO_PrintArg = " & 
                -- cinfo("---");
                -- FIO_PrintArg(
                --     f       => dump_file,
                --     L       => L,
                --     format  => "%d\n",
                --     pointer => pointer,
                --     arg     => fo(1));
                -- cinfo(L.all);
            end if;
        end loop;

        if not active_python_runner(runner_cfg) then
            get_checker_stat(stat);
            cinfo(LF & "Result:" & LF & to_string(stat));
        end if;

        test_runner_cleanup(runner);
        wait;
    end process;


end architecture;
