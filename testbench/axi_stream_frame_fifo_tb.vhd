--
-- FPGA Cores -- An HDL core library
--
-- Copyright 2014-2016 by Andre Souto (suoto)
--
-- This file is part of FPGA Cores.
--
-- FPGA Cores is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- FPGA Cores is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with FPGA Cores.  If not, see <http://www.gnu.org/licenses/>.

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
use fpga_cores_sim.axi_stream_bfm_pkg.all;

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

  subtype frame_t is data_tuple_array_t(open)(tdata(DATA_WIDTH - 1 downto 0), tuser(0 downto 0));

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
  axi_master_bfm_u : entity fpga_cores_sim.axi_stream_bfm
    generic map (
      TDATA_WIDTH => DATA_WIDTH,
      TUSER_WIDTH => 1,
      TID_WIDTH   => 0)
    port map (
      -- Usual ports
      clk        => clk,
      rst        => rst,
      -- AXI stream output
      m_tready   => m_axi.tready,
      m_tdata    => m_axi.tdata,
      m_tuser(0) => m_axi.tlast,
      m_tvalid   => m_axi.tvalid,
      m_tlast    => open);


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
      for i in frame'range loop
        frame(i).tdata := wr_data_gen.RandSlv(DATA_WIDTH);
        frame(i).tuser := (others => '0');
      end loop;
      frame(length - 1).tuser := (others => '1');
      return frame;
    end;
    --
    -- Generate a frame without tlast to check if the read side is never active before an
    -- entire frame is written
    --
    procedure test_frame_contention is
      variable frame    : frame_t(0 to FIFO_DEPTH/8 - 1);
      variable data     : frame_ptr_t;
      variable msg      : msg_t;
      variable expected : data_tuple_t(tdata(DATA_WIDTH - 1 downto 0), tuser(0 downto 0));
    begin
      for i in 0 to FIFO_DEPTH/8 - 1 loop
        frame(i).tdata := std_logic_vector(to_unsigned(i, DATA_WIDTH));
        frame(i).tuser := (others => '0'); -- No tlast at all
      end loop;

      cfg_rd_probability <= 1.0;
      axi_bfm_write(net,
        bfm         => axi_master,
        data        => frame,
        probability => 1.0,
        blocking    => False);

      walk(2*frame'length);

      check_false(has_message(self), "Did not expect anything to be received");
      check_equal(s_axi.tvalid, '0');
      check_equal(full, '0', "Expected FIFO to be full");
      check_equal(empty, '1', "Didn't expect FIFO to be empty");

      -- Generate a single tlast and check the frame is received
      axi_bfm_write(net,
        bfm         => axi_master,
        data        => data_tuple_array_t'(0 to 0 => (tdata => (DATA_WIDTH - 1 downto 0 => '0'), tuser => (0 downto 0 => '1'))),
        probability => 1.0,
        blocking    => True);

      wait until rising_edge(clk) and s_axi.tvalid = '1' and s_axi.tlast = '1' for 4*CLK_PERIOD;

      check_false(has_message(self), "Did not expect anything to be received");
      check_equal(full, '0', "Expected FIFO to be full");
      check_equal(empty, '0', "Didn't expect FIFO to be empty");

      -- Check the frame received is actually correct
      receive(net, self, msg);
      data := new frame_t'(pop(msg));
      for word in 0 to data'length - 1 loop
        if word = data'length - 1 then
          expected.tdata := (others => '0');
          expected.tuser := (others => '1');
        else
          expected.tdata := std_logic_vector(to_unsigned(word, DATA_WIDTH));
          expected.tuser := (others => '0');
        end if;

        if data(word) /= expected then
          error(
            sformat(
              "Word %d: expected %r but got %r",
              fo(word),
              fo(expected),
              fo(data(word))));
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
      variable expected         : data_tuple_t(tdata(DATA_WIDTH - 1 downto 0), tuser(0 downto 0));
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

      for frame in 0 to number_of_frames - 1 loop
        receive(net, self, msg);
        data := new frame_t'(pop(msg));
        debug(logger, sformat("Checking frame %d (length is %d)", fo(frame), fo(data'length)));
        expected.tuser := (others => '0'); -- tuser here is used only to pass tvalid
        for word in 0 to data'length - 1 loop
          expected.tdata := rd_data_gen.RandSlv(DATA_WIDTH);
          if word = data'length - 1 then
            expected.tuser := (others => '1');
          end if;

          if data(word) /= expected then
            error(
              sformat(
                "Frame %d, word %d: expected %r but got %r",
                fo(frame),
                fo(word),
                fo(expected),
                fo(data(word))));
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
      variable expected         : data_tuple_t(tdata(DATA_WIDTH - 1 downto 0), tuser(0 downto 0));
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
        expected.tuser := (others => '0'); -- tuser here is used only to pass tvalid
        for word in 0 to data'length - 1 loop
          expected.tdata := rd_data_gen.RandSlv(DATA_WIDTH);
          if word = data'length - 1 then
            expected.tuser := (others => '1');
          end if;

          if data(word) /= expected then
            error(
              sformat(
                "Frame %d, word %d: expected %r but got %r",
                fo(frame),
                fo(word),
                fo(expected),
                fo(data(word))));
          end if;
        end loop;
        debug(logger, sformat("Finished checking frame %d", fo(frame)));
      end loop;

    end;

      --
      variable stat   : checker_stat_t;
      -- variable filter : log_filter_t;
  begin

    -- Start both wr and rd data random generators with the same seed so we get the same
    -- sequence
    wr_data_gen.InitSeed("some_seed");
    rd_data_gen.InitSeed("some_seed");

    show(display_handler, debug);
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      cfg_rd_probability <= 0.0;
      join(net, axi_master);

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

      cfg_rd_probability <= 0.0;
      walk(16);
    end loop;

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
      if s_axi.tlast = '1' then
        push(msg, data_tuple_t'(tdata => s_axi.tdata, tuser => (0 downto 0 => '1')));
      else
        push(msg, data_tuple_t'(tdata => s_axi.tdata, tuser => (0 downto 0 => '0')));
      end if;

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
