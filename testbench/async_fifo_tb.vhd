--
-- FPGA core library
--
-- Copyright 2014-2022 by Andre Souto (suoto)
--
-- This source describes Open Hardware and is licensed under the CERN-OHL-W v2
--
-- You may redistribute and modify this documentation and make products using it
-- under the terms of the CERN-OHL-W v2 (https:/cern.ch/cern-ohl).This
-- documentation is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY,
-- INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A
-- PARTICULAR PURPOSE. Please see the CERN-OHL-W v2 for applicable conditions.
--
-- Source location: https://github.com/suoto/fpga_cores
--
-- As per CERN-OHL-W v2 section 4.1, should You produce hardware based on these
-- sources, You must maintain the Source Location visible on the external case
-- of the FPGA Cores or other product you make using this documentation.


-- vunit: run_all_in_same_sim

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library osvvm;
use osvvm.RandomPkg.all;

library fpga_cores;
use fpga_cores.common_pkg.all;

library str_format;
    use str_format.str_format_pkg.all;

entity async_fifo_tb is
    generic (
        runner_cfg       : string;
        wr_clk_period_ns : natural := 4;
        rd_clk_period_ns : natural := 16;
        WR_EN_RANDOM     : integer := 10;
        RD_EN_RANDOM     : integer := 10;
        SEED             : integer);
end async_fifo_tb;

architecture async_fifo_tb of async_fifo_tb is

    --
    procedure walk (
        signal   clk   : in std_logic;
        constant steps : natural := 1) is
    begin
        if steps /= 0 then
            for step in 0 to steps - 1 loop
                wait until rising_edge(clk);
            end loop;
        end if;
    end procedure;

    constant WR_CLK_PERIOD : time := WR_CLK_PERIOD_NS * 1 ns;
    constant RD_CLK_PERIOD : time := RD_CLK_PERIOD_NS * 1 ns;

    constant DATA_WIDTH         : integer := 16;
    constant UPPER_TRESHOLD     : integer := 500;
    constant LOWER_TRESHOLD     : integer := 10;

    signal wr_clk    : std_logic := '0';
    signal wr_arst   : std_logic;
    signal wr_en     : std_logic;
    signal wr_data   : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal wr_upper  : std_logic;
    signal wr_full   : std_logic;

    signal rd_clk    : std_logic := '0';
    signal rd_arst   : std_logic;
    signal rd_en     : std_logic;
    signal rd_dv     : std_logic;
    signal rd_data   : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal rd_empty  : std_logic;

    shared variable wr_data_gen : RandomPType;
    shared variable rd_data_gen : RandomPType;
    shared variable random_gen  : RandomPType;

begin

    -------------------
    -- Port mappings --
    -------------------
    dut : entity fpga_cores.async_fifo
        generic map (
            FIFO_LEN        => 512,
            DATA_WIDTH      => DATA_WIDTH,
            UPPER_TRESHOLD  => UPPER_TRESHOLD,
            LOWER_TRESHOLD  => LOWER_TRESHOLD,
            OVERFLOW_ACTION => "SATURATE",
            UNDERFLOW_ACTION=> "SATURATE")
        port map (
            -- Write port
            wr_clk      => wr_clk,
            wr_arst     => wr_arst,
            wr_data     => wr_data,
            wr_en       => wr_en,
            wr_full     => wr_full,
            wr_upper    => wr_upper,

            rd_clk      => rd_clk,
            rd_arst     => rd_arst,
            rd_data     => rd_data,
            rd_en       => rd_en,
            rd_dv       => rd_dv,
            rd_empty    => rd_empty);

    ------------------------------
    -- Asynchronous assignments --
    ------------------------------
    wr_clk <= not wr_clk after WR_CLK_PERIOD/2;
    rd_clk <= not rd_clk after RD_CLK_PERIOD/2;

    wr_arst <= '1', '0' after 16*RD_CLK_PERIOD;
    rd_arst <= '1', '0' after 16*RD_CLK_PERIOD;

    test_runner_watchdog(runner, 1 ms);

    ---------------
    -- Processes --
    ---------------
    wr_side : process
        --
        procedure write_data (
            constant d : std_logic_vector(DATA_WIDTH - 1 downto 0)) is
        begin
            if wr_full = '1' then
                wait until wr_full = '0';
            end if;
            verbose(sformat("Writing %r", fo(d)));
            wr_data <= d;
            wr_en   <= '1';
            walk(wr_clk, 1);
            wr_data <= (others => 'U');
            wr_en   <= '0';
        end procedure;

        --
        variable stat   : checker_stat_t;
        -- variable filter : log_filter_t;
    begin

        -- Start both wr and rd data random generators with the same seed so
        -- we get the same sequence
        wr_data_gen.InitSeed("some_seed");
        rd_data_gen.InitSeed("some_seed");
        random_gen.InitSeed(SEED);

        -- checker_init(display_format => verbose,
        --              file_name      => join(output_path(runner_cfg), "error.csv"),
        --              file_format    => verbose_csv);

        -- logger_init(display_format => verbose,
        --             file_name      => join(output_path(runner_cfg), "log.csv"),
        --             file_format    => verbose_csv);
        -- stop_level((debug, verbose), display_handler, filter);
        test_runner_setup(runner, runner_cfg);

        wait until wr_arst = '0';

        walk(wr_clk, 16);

        while test_suite loop
            for i in 0 to 1000 loop
                write_data(wr_data_gen.RandSlv(DATA_WIDTH));
                walk(wr_clk, random_gen.RandInt(WR_EN_RANDOM));
            end loop;
            wait for 1 us;
        end loop;

        if not active_python_runner(runner_cfg) then
            get_checker_stat(stat);
            warning(LF & "Result:" & LF & to_string(stat));
        end if;

        test_runner_cleanup(runner);
        wait;
    end process;

    rd_side : process
    begin

        wait until rd_arst = '0';

        while True loop
            walk(rd_clk, 1);
            if rd_dv = '1' then
                check_equal(rd_data, rd_data_gen.RandSlv(DATA_WIDTH));
            end if;
        end loop;

        wait;
    end process;

    rd_en_randomize : process
    begin
        rd_en <= '0';
        wait until rd_arst = '0';
        walk(rd_clk, 10);

        if RD_EN_RANDOM = 0 then
            rd_en <= '1';
            wait;
        else
            while True loop
                rd_en <= '1';
                walk(rd_clk, random_gen.RandInt(RD_EN_RANDOM));
                rd_en <= '0';
                walk(rd_clk, random_gen.RandInt(RD_EN_RANDOM));
            end loop;
        end if;
    end process;

end async_fifo_tb;

