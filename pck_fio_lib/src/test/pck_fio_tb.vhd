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
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;

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

        while test_suite loop
            wait for 10 us;
        end loop;

        if not active_python_runner(runner_cfg) then
            get_checker_stat(stat);
            info(LF & "Result:" & LF & to_string(stat));
        end if;

        test_runner_cleanup(runner);
        wait;
    end process;


end architecture;
