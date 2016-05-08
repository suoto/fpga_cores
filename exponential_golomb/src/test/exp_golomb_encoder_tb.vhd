---------------
-- Libraries --
---------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;

library exp_golomb_tb_lib;

library exp_golomb_lib;
    use exp_golomb_lib.exp_golomb_pkg;

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
    dut : entity exp_golomb_lib.exp_golomb_encoder
        generic map (
            DATA_WIDTH   => DATA_WIDTH
        )
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
            axi_out_tready => axi_out_tready 
        );

    file_dump_u : entity exp_golomb_tb_lib.file_dumper
        generic map (
            FILENAME => "output.bin",
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            clk     => clk,
            clken   => '1',
            rst     => rst,

            -- Data input
            tdata   => axi_out_tdata,
            tvalid  => axi_out_tvalid,
            tready  => axi_out_tready
        );
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
                bin_width_result := exp_golomb_lib.exp_golomb_pkg.bin_width(data);
                check_equal(
                    bin_width_result,
                    exp_golomb_lib.exp_golomb_pkg.numbits(i));
                end loop;

            data := to_unsigned(32, DATA_WIDTH);
            bin_width_result := exp_golomb_lib.exp_golomb_pkg.bin_width(data);
            check_equal(
                bin_width_result,
                exp_golomb_lib.exp_golomb_pkg.numbits(32));

            for i in 29 downto 2 loop
                for offset in -2 to 2 loop
                    data := to_unsigned(2**i + offset, DATA_WIDTH);
                    bin_width_result := exp_golomb_lib.exp_golomb_pkg.bin_width(data);
                    check_equal(
                        bin_width_result,
                        exp_golomb_lib.exp_golomb_pkg.numbits(2**i + offset));
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
        variable filter : log_filter_t;

    begin
        checker_init(display_format => verbose,
        file_name => join(output_path(runner_cfg), "error.csv"),
        file_format => verbose_csv);
        logger_init(display_format => verbose,
        file_name => join(output_path(runner_cfg), "log.csv"),
        file_format => verbose_csv);
        stop_level((debug, verbose), display_handler, filter);
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
