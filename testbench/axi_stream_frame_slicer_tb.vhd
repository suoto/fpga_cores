--
-- FPGA core library
--
-- Copyright 2014 by Andre Souto (suoto)
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

library fpga_cores;
use fpga_cores.common_pkg.all;

library fpga_cores_sim;
use fpga_cores_sim.axi_stream_bfm_pkg.all;

entity axi_stream_frame_slicer_tb is
    generic (
      RUNNER_CFG : string;
      SEED       : integer
    );
end axi_stream_frame_slicer_tb;

architecture axi_stream_frame_slicer_tb of axi_stream_frame_slicer_tb is

  ---------------
  -- Constants --
  ---------------
  constant CLK_PERIOD         : time    := 5 ns;
  constant FRAME_LENGTH_WIDTH : integer := 8;
  constant TDATA_WIDTH        : integer := 8;

  -----------
  -- Types --
  -----------
  type axi_stream_t is record
    tdata  : std_logic_vector(TDATA_WIDTH - 1 downto 0);
    tid    : std_logic_vector(FRAME_LENGTH_WIDTH - 1 downto 0);
    tvalid : std_logic;
    tready : std_logic;
    tlast  : std_logic;
  end record;


    -------------
    -- Signals --
    -------------
    -- Usual ports
    signal clk                 : std_logic := '1';
    signal rst                 : std_logic;

    signal axi_master          : axi_stream_t;
    signal axi_slave           : axi_stream_t;

    shared variable master_gen : RandomPType;
    shared variable slave_gen  : RandomPType;
    shared variable rand       : RandomPType;

    signal tvalid_probability  : real := 1.0;
    signal tready_probability  : real := 1.0;

    signal output_frame_length_count : integer := 0;

begin

  -------------------
  -- Port mappings --
  -------------------
  input_stream : entity fpga_cores_sim.axi_stream_bfm
    generic map (
      TDATA_WIDTH => TDATA_WIDTH,
      TUSER_WIDTH => 0,
      TID_WIDTH   => FRAME_LENGTH_WIDTH,
      SEED        => SEED)
    port map (
      -- Usual ports
      clk      => clk,
      rst      => rst,
      -- AXI stream output
      m_tready => axi_master.tready,
      m_tdata  => axi_master.tdata,
      m_tuser  => open,
      m_tkeep  => open,
      m_tid    => axi_master.tid,
      m_tvalid => axi_master.tvalid,
      m_tlast  => axi_master.tlast);


  dut : entity fpga_cores.axi_stream_frame_slicer
    generic map (
      FRAME_LENGTH_WIDTH => FRAME_LENGTH_WIDTH,
      TDATA_WIDTH        => TDATA_WIDTH)
    port map (
      -- Usual ports
      clk          => clk,
      rst          => rst,

      frame_length => axi_master.tid,

      -- Input stream
      s_tvalid     => axi_master.tvalid,
      s_tready     => axi_master.tready,
      s_tdata      => axi_master.tdata,
      s_tlast      => axi_master.tlast,

      -- Output stream
      m_tvalid     => axi_slave.tvalid,
      m_tready     => axi_slave.tready,
      m_tdata      => axi_slave.tdata,
      m_tlast      => axi_slave.tlast);

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  clk <= not clk after CLK_PERIOD/2;
  rst <= '1', '0' after 16*CLK_PERIOD;

  test_runner_watchdog(runner, 10 ms);

  ---------------
  -- Processes --
  ---------------
  main : process
    constant logger         : logger_t         := get_logger("main");
    constant expected_queue : actor_t          := find("expected_queue");
    variable input_stream   : axi_stream_bfm_t := create_bfm;
    variable frame_count    : integer          := 0;

    procedure walk(constant steps : natural) is
    begin
      if steps /= 0 then
        for step in 0 to steps - 1 loop
          wait until rising_edge(clk);
        end loop;
      end if;
    end procedure walk;

    impure function random_frame (constant length, data_width : natural)
      return           std_logic_array_t is
      variable frame : std_logic_array_t(0 to length - 1)(data_width - 1 downto 0);
    begin
        for i in 0 to length - 1 loop
            frame(i) := master_gen.RandSlv(data_width);
        end loop;
        return frame;
    end function random_frame;

    procedure run_test is
      constant frame_length        : integer := rand.RandInt(64) + 1;
      constant sliced_frame_length : integer := rand.RandInt(frame_length) + 1;
      constant data                : std_logic_array_t := random_frame(frame_length, TDATA_WIDTH);
      variable remainder           : integer;
      variable msg                 : msg_t;
    begin

      info(logger, sformat("Slicing %d beats into %d", fo(frame_length), fo(sliced_frame_length)));

      remainder := frame_length;

      for i in 0 to frame_length / sliced_frame_length - 1 loop
        info(
          logger,
          sformat(
            "[Frame count: %d] Inserting frame with length is %d",
            fo(frame_count),
            fo(sliced_frame_length)
          )
        );

        msg := new_msg;
        push(msg, sliced_frame_length);
        send(net, expected_queue, msg);
        frame_count := frame_count + 1;
      end loop;

      if frame_length mod sliced_frame_length /= 0 then
        info(
          logger,
          sformat(
            "[Frame count: %d] Inserting frame with length is %d",
            fo(frame_count),
            fo(frame_length mod sliced_frame_length)
          )
        );
        msg := new_msg;
        push(msg, frame_length mod sliced_frame_length);
        send(net, expected_queue, msg);
        frame_count := frame_count + 1;
      end if;

      axi_bfm_write(net,
        bfm         => input_stream,
        data        => data,
        tid         => std_logic_vector(to_unsigned(sliced_frame_length, FRAME_LENGTH_WIDTH)),
        probability => tvalid_probability);

      info(
        logger,
        sformat(
          "[Frame count: %d] Frame length %d, slice_frame length %d, remainder is %d",
          fo(frame_count),
          fo(remainder)
        )
      );

    end procedure run_test; -- }} ------------------------------------------------------

  begin

    -- Start both wr and rd data random generators with the same seed so we get the
    -- same sequence
    master_gen.InitSeed("some_seed");
    slave_gen.InitSeed("some_seed");
    rand.InitSeed(SEED);

    -- show(display_handler, debug);
    -- hide(get_logger("axi_stream_master_bfm"), display_handler, (Trace, Debug, Info), True);
    test_runner_setup(runner, RUNNER_CFG);

    while test_suite loop
      tvalid_probability <= 1.0;
      tready_probability <= 1.0;

      if run("back_to_back") then
        tready_probability <= 1.0;
        tready_probability <= 1.0;

        for i in 0 to 1023 loop
          run_test;
        end loop;
      elsif run("slow_master") then
        for i in 0 to 15 loop
          tvalid_probability <= rand.RandReal(1.0);

          for j in 0 to 63 loop
            run_test;
          end loop;
        end loop;
      elsif run("slow_slave") then
        for i in 0 to 15 loop
          tready_probability <= rand.RandReal(1.0);

          for j in 0 to 63 loop
            run_test;
          end loop;
        end loop;
      elsif run("slow_master_and_slave") then
        for i in 0 to 15 loop
          tvalid_probability <= rand.RandReal(1.0);
          tready_probability <= rand.RandReal(1.0);

          for j in 0 to 63 loop
            run_test;
          end loop;
        end loop;
      end if;

      walk(1);

      info("Done");
      walk(16);

    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

  axi_slave_p : process(clk, rst)
  begin
    if rst then
      axi_slave.tready <= '0';
    elsif rising_edge(clk) then
      axi_slave.tready <= '0';

      if rand.RandReal(1.0) < tready_probability then
        axi_slave.tready <= '1';
      end if;

      if axi_slave.tready = '1' and axi_slave.tvalid = '1' then
        -- info(sformat("Received %r", fo(axi_slave.tdata)));
        check_equal(axi_slave.tdata, slave_gen.RandSlv(TDATA_WIDTH));
      end if;
    end if;
  end process;

  output_p : process
    constant logger         : logger_t := get_logger("output_p");
    constant expected_queue : actor_t  := find("received_queue");
    variable msg            : msg_t;
    variable frame_count    : integer  := 0;
    variable length_count   : integer  := 0;
  begin
    wait until rst = '0';
    while True loop
      wait until rising_edge(clk) and axi_slave.tvalid = '1' and axi_slave.tready = '1';
      length_count := length_count + 1;
      output_frame_length_count <= output_frame_length_count + 1;

      if axi_slave.tlast then
        -- Notify the main process the length of the frames we get
        msg := new_msg;
        push(msg, length_count);
        send(net, expected_queue, msg);
        -- info(logger, sformat("Received frame %d, length is %d", fo(frame_count), fo(length_count)));
        length_count := 0;
        output_frame_length_count <= 0;
        frame_count  := frame_count + 1;
      end if;
    end loop;
  end process;

  checker : process
    constant logger         : logger_t := get_logger("checker");
    constant expected_queue : actor_t  := new_actor("expected_queue");
    constant received_queue : actor_t  := new_actor("received_queue");
    variable msg            : msg_t;
    variable frame_count    : integer  := 0;
    variable actual         : integer;
    variable expected       : integer;
  begin
    while True loop
      receive(net, expected_queue, msg);
      expected := pop(msg);

      receive(net, received_queue, msg);
      actual   := pop(msg);

      info(logger, sformat("Frame %d: Expected %d, got %d", fo(frame_count), fo(expected), fo(actual)));
      frame_count := frame_count + 1;
      check_equal(actual, expected);
    end loop;
    wait;
  end process;

end axi_stream_frame_slicer_tb;
