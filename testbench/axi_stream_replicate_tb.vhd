--
-- FPGA core library
--
-- Copyright 2020 by Andre Souto (suoto)
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
context vunit_lib.com_context;

library osvvm;
use osvvm.RandomPkg.all;

library str_format;
use str_format.str_format_pkg.all;

library fpga_cores_sim;
context fpga_cores_sim.sim_context;

library fpga_cores;
use fpga_cores.axi_pkg.all;
use fpga_cores.common_pkg.all;

entity axi_stream_replicate_tb is
  generic ( runner_cfg : string );
end axi_stream_replicate_tb;

architecture axi_stream_replicate_tb of axi_stream_replicate_tb is

  constant CLK_PERIOD : time     := 5 ns;
  constant INTERFACES : positive := 4;
  constant DATA_WIDTH : integer  := 8;

  type axi_stream_data_bus_array_t is array (0 to INTERFACES - 1) of axi_stream_data_bus_t(tdata(DATA_WIDTH - 1 downto 0));

  shared variable random_gen : RandomPType;

  signal clk                : std_logic := '0';
  signal rst                : std_logic;

  signal m_axi              : axi_stream_data_bus_t(tdata(DATA_WIDTH - 1 downto 0));
  signal s_axi              : axi_stream_data_bus_array_t;

  signal cfg_rd_probability : real_vector(0 to INTERFACES - 1) := (others => 1.0);

begin

  -------------------
  -- Port mappings --
  -------------------
  axi_master_bfm_u : entity fpga_cores_sim.axi_stream_bfm
    generic map (
      NAME        => "axi_master_bfm_u",
      TDATA_WIDTH => DATA_WIDTH
    )
    port map (
      -- Usual ports
      clk        => clk,
      rst        => rst,
      -- AXI stream output
      m_tready   => m_axi.tready,
      m_tdata    => m_axi.tdata,
      m_tvalid   => m_axi.tvalid,
      m_tlast    => open);

  dut : entity fpga_cores.axi_stream_replicate
    generic map (
      INTERFACES  => INTERFACES,
      TDATA_WIDTH => DATA_WIDTH)
    port map (
      -- Write port
      clk              => clk,
      rst              => rst,

      s_tvalid         => m_axi.tvalid,
      s_tready         => m_axi.tready,
      s_tdata          => m_axi.tdata,

      m_tvalid(3)      => s_axi(3).tvalid,
      m_tvalid(2)      => s_axi(2).tvalid,
      m_tvalid(1)      => s_axi(1).tvalid,
      m_tvalid(0)      => s_axi(0).tvalid,

      m_tready(3)      => s_axi(3).tready,
      m_tready(2)      => s_axi(2).tready,
      m_tready(1)      => s_axi(1).tready,
      m_tready(0)      => s_axi(0).tready,

      m_tdata(3)       => s_axi(3).tdata,
      m_tdata(2)       => s_axi(2).tdata,
      m_tdata(1)       => s_axi(1).tdata,
      m_tdata(0)       => s_axi(0).tdata);

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  clk <= not clk after CLK_PERIOD/2;

  test_runner_watchdog(runner, 20 us);

  ---------------
  -- Processes --
  ---------------
  main : process
    constant self       : actor_t  := new_actor("main");
    constant checker    : actor_t  := new_actor("checker");
    constant logger     : logger_t := get_logger("main");
    variable axi_master : axi_stream_bfm_t := create_bfm("axi_master_bfm_u");
    --
    procedure walk (constant steps : natural := 1) is
    begin
      if steps /= 0 then
        for step in 0 to steps - 1 loop
          wait until rising_edge(clk);
        end loop;
      end if;
    end procedure;

    procedure run_test (
      constant words    : integer := 16) is
      variable msg      : msg_t;
      variable expected : std_logic_array_t(0 to words - 1)(DATA_WIDTH - 1 downto 0);
      variable received : std_logic_vector(DATA_WIDTH - 1 downto 0);
    begin
      for i in 0 to words - 1 loop
        expected(i) := random_gen.RandSlv(DATA_WIDTH);
      end loop;

      info(logger, sformat("Sending: %s", fo(to_string(expected))));

      -- Send data
      axi_bfm_write(net,
        bfm         => axi_master,
        data        => expected,
        blocking    => False);

      for word_index in 0 to words - 1 loop
        for interface in 0 to INTERFACES - 1 loop
          receive(net, self, msg);
          received := pop(msg);
          check_equal(
            received,
            expected(word_index),
            sformat(
              "Interface %d, word %d: expected %r but got %r",
              fo(interface), fo(word_index), fo(expected(word_index)), fo(received)));
        end loop;
      end loop;
    end procedure;

    --
    variable stat   : checker_stat_t;
  begin

    show(display_handler, debug);
    test_runner_setup(runner, runner_cfg);

    rst <= '1';
    walk(16);
    rst <= '0';

    while test_suite loop
      cfg_rd_probability <= (others => 0.0);

      walk(16);

      set_timeout(runner, 2 us);

      if run("test_all_ready") then
        cfg_rd_probability <= (others => 1.0);
        walk(1);
        run_test;
      elsif run("test_1_slow_interface") then
        cfg_rd_probability <= (3 => 0.5, others => 1.0);
        walk(1);
        run_test;
      elsif run("test_2_slow_interfaces") then
        cfg_rd_probability <= (2 => 0.9, 3 => 0.8, others => 1.0);
        walk(1);
        run_test;
      elsif run("test_all_slow_interfaces") then
        cfg_rd_probability <= (others => 0.9);
        walk(1);
        run_test(words => 256);
      elsif run("test_tvalid_before_tready") then
        cfg_rd_probability <= (others => 0.9);
        run_test(words => 256);
      end if;

      join(net, axi_master);

      walk(16);

      if has_message(self) then
        failure("There should not be any messages from the receiver by now");
      end if;

    end loop;

    cfg_rd_probability <= (others => 0.0);

    if not active_python_runner(runner_cfg) then
      get_checker_stat(stat);
      warning(logger, LF & "Result:" & LF & to_string(stat));
    end if;

    test_runner_cleanup(runner);
    wait;
  end process;

  g_readers : for i in 0 to INTERFACES - 1 generate
    checker : process
      constant self        : actor_t := find("checker" & integer'image(i));
      constant main        : actor_t := find("main");
      constant logger      : logger_t := get_logger("checker" & integer'image(i));
      variable msg         : msg_t;
    begin

      wait until rst = '0';

      while True loop
        wait until s_axi(i).tvalid = '1' and s_axi(i).tready = '1' and rising_edge(clk);
        info(logger, sformat("Received %r", fo(s_axi(i).tdata)));
        msg := new_msg;
        push(msg, s_axi(i).tdata);
        send(net, main, msg);
      end loop;

      wait;
    end process;

    rd_en_randomize : process
    begin
      s_axi(i).tready <= '0';
      wait until rst = '0';

      while True loop
        wait until rising_edge(clk);
        if random_gen.RandReal(1.0) < cfg_rd_probability(i) then
          s_axi(i).tready <= '1';
        else
          s_axi(i).tready <= '0';
        end if;
      end loop;
    end process;
  end generate;


end axi_stream_replicate_tb;
