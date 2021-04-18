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

entity axi_stream_frame_fifo_tb is
  generic (runner_cfg : string);
end axi_stream_frame_fifo_tb;

architecture axi_stream_frame_fifo_tb of axi_stream_frame_fifo_tb is

  constant CLK_PERIOD         : time := 5 ns;
  constant FIFO_DEPTH         : integer := 256;
  constant DATA_WIDTH         : integer := 8;

  shared variable wr_data_gen : RandomPType;
  shared variable rd_data_gen : RandomPType;
  shared variable random_gen  : RandomPType;

  signal clk                  : std_logic := '0';
  signal rst                  : std_logic;

  signal m_axi                : axi_stream_data_bus_t(tdata(DATA_WIDTH - 1 downto 0));
  signal s_axi                : axi_stream_data_bus_t(tdata(DATA_WIDTH - 1 downto 0));

  signal entries              : std_logic_vector(numbits(FIFO_DEPTH) downto 0);
  signal empty                : std_logic;
  signal full                 : std_logic;

  signal cfg_rd_probability       : real := 1.0;

  -- AXI BFM works with multiples of 8, add an extra byte to carry tlast
  subtype frame_t is std_logic_array_t(open)(DATA_WIDTH + 8 - 1 downto 0);

  type frame_ptr_t is access frame_t;

  impure function pop(msg : msg_t) return frame_t is
    constant length : integer := pop(msg);
    variable frame  : frame_t(0 to length - 1);
  begin
    for i in frame'range loop
      frame(i) := pop(msg);
    end loop;
    return frame;
  end;


begin

  -------------------
  -- Port mappings --
  -------------------
  bfm_block : block
    signal tdata : std_logic_vector(DATA_WIDTH + 8 - 1 downto 0);
  begin
    axi_master_bfm_u : entity fpga_cores_sim.axi_stream_bfm
      generic map ( TDATA_WIDTH => DATA_WIDTH + 8 )
      port map (
        -- Usual ports
        clk        => clk,
        rst        => rst,
        -- AXI stream output
        m_tready   => m_axi.tready,
        m_tdata    => tdata,
        m_tvalid   => m_axi.tvalid,
        m_tlast    => open);

    m_axi.tdata <= tdata(DATA_WIDTH - 1 downto 0);
    m_axi.tlast <= tdata(DATA_WIDTH);
  end block;


  dut : entity fpga_cores.axi_stream_frame_fifo
    generic map (
      FIFO_DEPTH => FIFO_DEPTH,
      DATA_WIDTH => DATA_WIDTH)
    port map (
      -- Write port
      clk      => clk,
      rst      => rst,

      entries  => entries,
      empty    => empty,
      full     => full,

      -- Write side
      s_tvalid => m_axi.tvalid,
      s_tready => m_axi.tready,
      s_tdata  => m_axi.tdata,
      s_tlast  => m_axi.tlast,

      -- Read side
      m_tvalid => s_axi.tvalid,
      m_tready => s_axi.tready,
      m_tdata  => s_axi.tdata,
      m_tlast  => s_axi.tlast);


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
    variable axi_master : axi_stream_bfm_t := create_bfm;
    --
    procedure walk (constant steps : natural := 1) is
    begin
      if steps /= 0 then
        for step in 0 to steps - 1 loop
          wait until rising_edge(clk);
        end loop;
      end if;
    end procedure;

    --
    impure function generate_frame ( constant length : natural ) return frame_t is
      variable frame : frame_t(0 to length - 1);
    begin
      for i in 0 to length - 1 loop
        if i = length - 1 then
          frame(i) := (6 downto 0 => 'U') & '1' & wr_data_gen.RandSlv(DATA_WIDTH);
        else
          frame(i) := (6 downto 0 => 'U') & '0' & wr_data_gen.RandSlv(DATA_WIDTH);
        end if;
      end loop;
      return frame;
    end;

    --
    -- Generate a frame without tlast to check if the read side is never active before an
    -- entire frame is written
    --
    procedure test_frame_contention is
      variable data     : frame_ptr_t;
      variable msg      : msg_t;
      variable expected : std_logic_vector(DATA_WIDTH + 8 - 1 downto 0);
    begin
      data := new frame_t(0 to FIFO_DEPTH/8 - 1);
      for i in 0 to FIFO_DEPTH/8 - 1 loop
        data(i) := (6 downto 0 => 'U') & '0' & std_logic_vector(to_unsigned(i, DATA_WIDTH));
      end loop;

      cfg_rd_probability <= 1.0;
      axi_bfm_write(net,
        bfm      => axi_master,
        data     => data.all,
        blocking => False);

      walk(2*data.all'length);

      deallocate(data);

      check_false(has_message(self), "Did not expect anything to be received");
      check_equal(s_axi.tvalid, '0');
      check_equal(full, '0', "Expected FIFO to be full");
      check_equal(empty, '1', "Didn't expect FIFO to be empty");

      -- Generate a single tlast with all ones as data and check the frame is received
      data    := new frame_t(0 to 0);
      data(0) := (6 downto 0 => 'U') & '1' & (DATA_WIDTH - 1 downto 0 => '1');
      axi_bfm_write(net,
        bfm      => axi_master,
        data     => data.all,
        blocking => True);
      deallocate(data);

      wait until rising_edge(clk) and s_axi.tvalid = '1' and s_axi.tlast = '1' for 4*CLK_PERIOD;
      if not s_axi.tvalid = '1' and s_axi.tlast = '1' then
        error(logger, "Timeout waiting to s_axi");
      end if;

      check_false(has_message(self), "Did not expect anything to be received");
      check_equal(full, '0', "Expected FIFO to be full");
      check_equal(empty, '0', "Didn't expect FIFO to be empty");

      -- Check the frame received is actually correct
      receive(net, self, msg);
      data := new frame_t'(pop(msg));
      for word in 0 to data'length - 1 loop
        if word = data'length - 1 then
          -- Last word we added manually as all ones
          expected := (6 downto 0 => 'U') & '1' & (DATA_WIDTH - 1 downto 0 => '1');
        else
          expected := (6 downto 0 => 'U') & '0' & std_logic_vector(to_unsigned(word, DATA_WIDTH));
        end if;

        if data(word)(DATA_WIDTH downto 0) /= expected(DATA_WIDTH downto 0) then
          error(logger, sformat("Word %d: expected %r but got %r", fo(word), fo(expected), fo(data(word))));
        end if;
      end loop;

      walk(1);

      check_false(has_message(self), "Did not expect anything to be received");
      check_equal(s_axi.tvalid, '0');
      check_equal(full, '0', "Expected FIFO to be full");
      check_equal(empty, '1', "Didn't expect FIFO to be empty");

    end;

    procedure test_data_integrity (
      constant number_of_frames : natural;
      constant length           : natural;
      constant wr_probability   : real;
      constant rd_probability   : real) is

      variable data             : frame_ptr_t;
      variable msg              : msg_t;
      variable expected         : std_logic_vector(DATA_WIDTH + 8 - 1 downto 0);
    begin
      cfg_rd_probability <= rd_probability;

      for frame in 0 to number_of_frames - 1 loop
        info(logger, sformat("Writing frame %d/%d, length is %d", fo(frame + 1), fo(number_of_frames), fo(length)));

        data := new frame_t'(generate_frame(length));
        axi_bfm_write(net,
          bfm         => axi_master,
          data        => data.all,
          probability => wr_probability,
          blocking    => False);
      end loop;

      join(net, axi_master);

      for frame in 0 to number_of_frames - 1 loop
        receive(net, self, msg);
        data := new frame_t'(pop(msg));
        debug(logger, sformat("Checking frame %d (length is %d)", fo(frame), fo(data'length)));
        for word in 0 to data'length - 1 loop
          if word = data'length - 1 then
            expected := (6 downto 0 => 'U') & '1' & rd_data_gen.RandSlv(DATA_WIDTH);
          else
            expected := (6 downto 0 => 'U') & '0' & rd_data_gen.RandSlv(DATA_WIDTH);
          end if;

          if data(word)(DATA_WIDTH downto 0) /= expected(DATA_WIDTH downto 0) then
            error(sformat("Frame %d, word %d: expected %r (last=%r) but got %r",
                          fo(frame), fo(word), fo(expected(DATA_WIDTH - 1 downto 0)),
                          fo(expected(DATA_WIDTH)), fo(data(word))));
          end if;
        end loop;
        debug(logger, sformat("Finished checking frame %d", fo(frame)));
      end loop;

    end;

    procedure test_random_frame_sizes (
      constant number_of_frames : natural;
      constant wr_probability   : real;
      constant rd_probability   : real) is

      variable length           : natural;
      variable data             : frame_ptr_t;
      variable msg              : msg_t;
      variable expected         : std_logic_vector(DATA_WIDTH + 8 - 1 downto 0);
    begin
      cfg_rd_probability <= rd_probability;
      for frame in 0 to number_of_frames - 1 loop
        length := random_gen.RandInt(1, FIFO_DEPTH - 1);
        info(logger, sformat("Writing frame %d/%d, length is %d", fo(frame + 1), fo(number_of_frames), fo(length)));

        data := new frame_t'(generate_frame(length));
        axi_bfm_write(net,
          bfm         => axi_master,
          data        => data.all,
          probability => wr_probability,
          blocking    => False);
      end loop;

      for frame in 0 to number_of_frames - 1 loop
        receive(net, self, msg);
        data := new frame_t'(pop(msg));
        debug(logger, sformat("Checking frame %d (length is %d)", fo(frame), fo(data'length)));
        for word in 0 to data'length - 1 loop

          if word = data'length - 1 then
            expected := (DATA_WIDTH - 1 downto 0 => '1') & rd_data_gen.RandSlv(DATA_WIDTH);
          else
            expected := (DATA_WIDTH - 1 downto 0 => '0') & rd_data_gen.RandSlv(DATA_WIDTH);
          end if;

          if data(word)(DATA_WIDTH downto 0) /= expected(DATA_WIDTH downto 0) then
            error(sformat("Frame %d, word %d: expected %r (last=%r) but got %r",
                          fo(frame), fo(word), fo(expected(DATA_WIDTH - 1 downto 0)),
                          fo(expected(DATA_WIDTH)), fo(data(word))));
          end if;
        end loop;
        debug(logger, sformat("Finished checking frame %d", fo(frame)));
      end loop;

    end;

      --
      variable stat   : checker_stat_t;
  begin

    -- Start both wr and rd data random generators with the same seed so we get the same
    -- sequence
    wr_data_gen.InitSeed("some_seed");
    rd_data_gen.InitSeed("some_seed");

    show(display_handler, debug);
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      cfg_rd_probability <= 0.0;

      rst <= '1';
      walk(16);
      rst <= '0';
      walk(16);

      set_timeout(runner, 100 us);

      if run("test_writing_half_of_fifo_depth") then
        test_data_integrity(
          number_of_frames => 8,
          length           => FIFO_DEPTH/2,
          wr_probability   => 1.0,
          rd_probability   => 1.0);
      elsif run("test_random_frame_sizes") then
        test_random_frame_sizes(
          number_of_frames => 8,
          wr_probability   => 1.0,
          rd_probability   => 1.0);

        test_random_frame_sizes(
          number_of_frames => 8,
          wr_probability   => 0.5,
          rd_probability   => 1.0);

        test_random_frame_sizes(
          number_of_frames => 8,
          wr_probability   => 1.0,
          rd_probability   => 0.5);

        test_random_frame_sizes(
          number_of_frames => 8,
          wr_probability   => 0.75,
          rd_probability   => 0.75);

      elsif run("test_frame_contention") then
        test_frame_contention;

      elsif run("test_writing_full_fifo_depth") then
        test_data_integrity(
          number_of_frames => 8,
          length           => FIFO_DEPTH,
          wr_probability   => 1.0,
          rd_probability   => 1.0);

      end if;

      join(net, axi_master);
      walk(16);
    end loop;

    cfg_rd_probability <= 0.0;

    if not active_python_runner(runner_cfg) then
      get_checker_stat(stat);
      warning(logger, LF & "Result:" & LF & to_string(stat));
    end if;

    test_runner_cleanup(runner);
    wait;
  end process;

  checker : process
    constant self        : actor_t := find("checker");
    constant main        : actor_t := find("main");
    constant logger      : logger_t := get_logger("checker");
    variable msg         : msg_t;
    variable word_count  : integer := 0;
    variable frame_count : integer := 0;

    procedure send_data is
      variable msg_with_size : msg_t := new_msg;
    begin
      info(logger, sformat("Sending frame with %d words", fo(word_count)));
      push(msg_with_size, word_count);
      while not is_empty(msg) loop
        push(msg_with_size, std_logic_vector'(pop(msg)));
      end loop;
      send(net, main, msg_with_size);
    end;

  begin

    wait until rst = '0';

    msg := new_msg;

    while True loop
      wait until s_axi.tvalid = '1' and s_axi.tready = '1' and rising_edge(clk);
      push(msg, std_logic_vector'((6 downto 0 => '0') & s_axi.tlast & s_axi.tdata));

      word_count := word_count + 1;

      if s_axi.tlast = '1' then
        debug(logger, sformat("End of frame %d detected at word %d", fo(frame_count), fo(word_count)));
        send_data;
        msg         := new_msg;
        frame_count := frame_count + 1;
        word_count  := 0;
      end if;
    end loop;

    wait;
  end process;

  rd_en_randomize : process
  begin
    s_axi.tready <= '0';
    wait until rst = '0';

    while True loop
      wait until rising_edge(clk);
      if random_gen.RandReal(1.0) < cfg_rd_probability then
        s_axi.tready <= '1';
      else
        s_axi.tready <= '0';
      end if;
    end loop;
  end process;

end axi_stream_frame_fifo_tb;
