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

library str_format;
use str_format.str_format_pkg.all;

library osvvm;
use osvvm.RandomPkg.all;

library fpga_cores;
use fpga_cores.common_pkg.all;

library fpga_cores_sim;
use fpga_cores_sim.testbench_utils_pkg.all;
use fpga_cores_sim.axi_stream_bfm_pkg.all;

entity axi_stream_width_converter_tb is
  generic (
    RUNNER_CFG        : string;
    INPUT_DATA_WIDTH  : natural := 24;
    OUTPUT_DATA_WIDTH : natural := 16;
    SEED              : integer);
end axi_stream_width_converter_tb;

architecture axi_stream_width_converter_tb of axi_stream_width_converter_tb is

  ---------------
  -- Constants --
  ---------------
  constant CLK_PERIOD        : time := 5 ns;
  constant INPUT_BYTE_WIDTH  : natural := (INPUT_DATA_WIDTH + 7) / 8;
  constant OUTPUT_BYTE_WIDTH : natural := (OUTPUT_DATA_WIDTH + 7) / 8;
  constant AXI_TID_WIDTH     : natural := 8;

  constant TEST_FRAMES : positive := 64;

  type test_frame_t is record
    data        : byte_array_t;
    id          : std_logic_vector;
    probability : real range 0.0 to 1.0;
  end record;

  procedure push(msg : msg_t; frame : test_frame_t ) is
  begin
    push(msg, frame.probability);
    push(msg, frame.id);
    push(msg, frame.data);
  end;

  impure function pop(msg : msg_t) return test_frame_t is
    constant probability : real             := pop(msg);
    constant id          : std_logic_vector := pop(msg);
    constant data        : byte_array_t     := pop(msg);
    constant frame       : test_frame_t     := (data => data, id => id, probability => probability);
  begin
    return frame;
  end;

  -------------
  -- Signals --
  -------------
  -- Usual ports
  signal clk                : std_logic := '1';
  signal rst                : std_logic;

  signal tvalid_probability : real range 0.0 to 1.0 := 1.0;
  signal tready_probability : real range 0.0 to 1.0 := 1.0;

  -- AXI input
  signal m_tready           : std_logic := '1';
  signal m_tvalid           : std_logic;
  signal m_tdata            : std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);
  signal m_tkeep            : std_logic_vector(INPUT_BYTE_WIDTH - 1 downto 0);
  signal m_tid              : std_logic_vector(AXI_TID_WIDTH - 1 downto 0);
  signal m_tlast            : std_logic;
  signal m_data_valid       : boolean;

  signal s_tready           : std_logic;
  signal s_tvalid           : std_logic;
  signal s_tdata            : std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);
  signal s_tkeep            : std_logic_vector(OUTPUT_BYTE_WIDTH - 1 downto 0);
  signal s_tid              : std_logic_vector(AXI_TID_WIDTH - 1 downto 0);
  signal s_tlast            : std_logic;
  signal s_data_valid       : boolean;

begin

  -------------------
  -- Port mappings --
  -------------------
  dut : entity fpga_cores.axi_stream_width_converter
    generic map (
      INPUT_DATA_WIDTH    => INPUT_DATA_WIDTH,
      OUTPUT_DATA_WIDTH   => OUTPUT_DATA_WIDTH,
      AXI_TID_WIDTH       => AXI_TID_WIDTH)
    port map (
      -- Usual ports
      clk      => clk,
      rst      => rst,
      -- AXI stream input
      s_tready => m_tready,
      s_tdata  => m_tdata,
      s_tkeep  => m_tkeep,
      s_tid    => m_tid,
      s_tvalid => m_tvalid,
      s_tlast  => m_tlast,
      -- AXI stream output
      m_tready => s_tready,
      m_tdata  => s_tdata,
      m_tkeep  => s_tkeep,
      m_tid    => s_tid,
      m_tvalid => s_tvalid,
      m_tlast  => s_tlast);

  axi_stream_write : entity fpga_cores_sim.axi_stream_bfm
    generic map (
      TDATA_WIDTH => INPUT_DATA_WIDTH,
      TID_WIDTH   => AXI_TID_WIDTH,
      SEED        => SEED)
    port map (
      -- Usual ports
      clk      => clk,
      rst      => rst,
      -- AXI stream output
      m_tready => m_tready,
      m_tdata  => m_tdata,
      m_tkeep  => m_tkeep,
      m_tid    => m_tid,
      m_tvalid => m_tvalid,
      m_tlast  => m_tlast);

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  clk <= not clk after CLK_PERIOD/2;

  test_runner_watchdog(runner, 2 ms);

  m_data_valid <= m_tvalid = '1' and m_tready = '1';
  s_data_valid <= s_tvalid = '1' and s_tready = '1';

  ---------------
  -- Processes --
  ---------------
  main : process -- {{
    constant self   : actor_t := new_actor("main");
    variable rand   : RandomPType;
    variable master : axi_stream_bfm_t := create_bfm;

    ------------------------------------------------------------------------------------
    procedure walk(constant steps : natural) is
    begin
      if steps /= 0 then
        for step in 0 to steps - 1 loop
          wait until rising_edge(clk);
        end loop;
      end if;
    end procedure walk;

    ------------------------------------------------------------------------------------
    procedure send_frame ( constant frame : test_frame_t ) is
      variable msg : msg_t := new_msg(sender => self);
    begin
      info("Sending frame");
      push(msg, frame);
      send(net, find("checker_p"), msg);
    end;

    ------------------------------------------------------------------------------------
    procedure test_frame ( constant id   : std_logic_vector(AXI_TID_WIDTH - 1 downto 0);
                           constant data : std_logic_array_t ) is

      constant frame : test_frame_t := (data => data, id => id, probability => tready_probability);
    begin
      info(sformat("Writing frame: id=%r, length=%d bytes (%d bits), data=%s" & cr, fo(id), fo(data'length), fo(8*data'length), to_string(data)));

      send_frame(frame);

      axi_bfm_write(net,
        bfm         => master,
        data        => reinterpret(data, INPUT_DATA_WIDTH),
        tid         => id,
        probability => tvalid_probability,
        blocking    => True);

    end;

    ------------------------------------------------------------------------------------
    procedure run_test ( constant frames : positive ) is
    begin
      for i in 0 to frames - 1 loop
        info(sformat("Writing frame %d", fo(i)));
        test_frame(
          id => rand.RandSlv(AXI_TID_WIDTH),
          data => random(4*rand.RandInt(INPUT_BYTE_WIDTH*OUTPUT_BYTE_WIDTH) + 1)
        );
      end loop;

    end;
    ------------------------------------------------------------------------------------


  begin
    rand.InitSeed("main" & integer'image(SEED));

    test_runner_setup(runner, RUNNER_CFG);
    show(display_handler, debug);

    while test_suite loop
      rst <= '1';
      walk(4);
      rst <= '0';
      walk(4);

      tvalid_probability <= 1.0;
      tready_probability <= 1.0;

      if run("back_to_back") then
        tvalid_probability <= 1.0;
        tready_probability <= 1.0;
        run_test(TEST_FRAMES);

      elsif run("slow_master") then
        tvalid_probability <= 0.5;
        tready_probability <= 1.0;
        run_test(TEST_FRAMES);

      elsif run("slow_slave") then
        tvalid_probability <= 1.0;
        tready_probability <= 0.5;
        run_test(TEST_FRAMES);

      elsif run("slow_master_and_slave") then
        tvalid_probability <= 0.75;
        tready_probability <= 0.75;
        run_test(TEST_FRAMES);

      elsif run("test_partial_words") then

        for i in 0 to TEST_FRAMES loop
          for base_width in 0 to max(INPUT_BYTE_WIDTH, OUTPUT_BYTE_WIDTH) - 1 loop
            test_frame(
              id => rand.RandSlv(AXI_TID_WIDTH),
              data => random(2*base_width + 1)
            );
          end loop;
        end loop;

      end if;

      join(net, master);

      walk(32);

    end loop;

    test_runner_cleanup(runner);
    wait;
  end process; -- }}

  checker_p : process -- {{
    constant self      : actor_t := new_actor("checker_p");
    constant logger    : logger_t := get_logger("checker_p");
    constant main      : actor_t := find("main");
    variable msg       : msg_t;
    variable frame_cnt : natural := 0;

    ------------------------------------------------------------------------------------
    procedure check_frame ( constant frame : test_frame_t ) is
      constant resized_data : std_logic_array_t := reinterpret(frame.data, OUTPUT_DATA_WIDTH);
      variable exp_tkeep    : std_logic_vector(OUTPUT_BYTE_WIDTH - 1 downto 0);
      variable word_cnt     : natural := 0;
      variable failed       : boolean := False;

      ------------------------------------------------------------------------------------
      procedure check_word (
        constant data : std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);
        constant mask : std_logic_vector(OUTPUT_BYTE_WIDTH - 1 downto 0);
        constant id   : std_logic_vector(AXI_TID_WIDTH - 1 downto 0);
        constant last : boolean := False) is
      begin
          wait until s_tvalid = '1' and s_tready = '1' and rising_edge(clk);

          if data /= s_tdata then
            warning(
              logger,
              sformat(
                "TDATA ERROR @ frame %d, word %d: Got %r, expected %r",
                fo(frame_cnt),
                fo(word_cnt),
                fo(s_tdata),
                fo(data)
              )
            );
            failed := True;
          end if;

          if id /= s_tid then
            warning(
              logger,
              sformat(
                "TID   ERROR @ frame %d, word %d: Got %r, expected %r",
                fo(frame_cnt),
                fo(word_cnt),
                fo(s_tid),
                fo(id)
              )
            );
            failed := True;
          end if;

          if mask /= s_tkeep then
            warning(
              logger,
              sformat(
                "TKEEP ERROR @ frame %d, word %d: Got %r, expected %r",
                fo(frame_cnt),
                fo(word_cnt),
                fo(s_tkeep),
                fo(mask)
              )
            );
            failed := True;
          end if;

          if (last and s_tlast /= '1') or (not last and s_tlast /= '0') then
            warning(
              logger,
              sformat(
                "TLAST ERROR @ frame %d, word %d: Got %s, expected %s",
                fo(frame_cnt),
                fo(word_cnt),
                fo(s_tlast),
                fo(last)
              )
            );
            failed := True;
          end if;

          word_cnt  := word_cnt + 1;

      end;

    begin

      for i in 0 to resized_data'length - 1 loop

        if i = resized_data'length - 1 then
          exp_tkeep := (others => '0');
          exp_tkeep((8*frame.data'length mod OUTPUT_DATA_WIDTH)/8 - 1 downto 0) := (others => '1');

          -- If data has an integer number of output data width, then all bytes are
          -- valid on the last word
          if exp_tkeep = (exp_tkeep'range => '0') then
            exp_tkeep := (others => '1');
          end if;

          debug(
            logger,
            sformat(
              "[%d] %r || %d bytes, remainder=%d, exp tkeep=%b",
              fo(i),
              fo(resized_data(i)),
              fo(8*frame.data'length),
              fo(8*frame.data'length mod OUTPUT_DATA_WIDTH),
              fo(exp_tkeep)
            )
          );
          check_word(resized_data(i), exp_tkeep, frame.id, True);
        else
          check_word(resized_data(i), (others => '0'), frame.id, False);
        end if;
      end loop;

      if failed then
        error(
          logger,
          sformat(
          "Some tests failed while checking frame: id=%r, data'lengh=%d. Original data was: %s Resized data: %s",
            fo(frame.id),
            fo(resized_data'length),
            to_string(frame.data) & cr & cr,
            to_string(resized_data)
          )
        );
      end if;

    end;

  begin
    receive(net, self, msg);
    info(logger, "Received frame");
    check_frame(pop(msg));
    frame_cnt := frame_cnt + 1;
    wait;
  end process; -- }}

  -- Controls the slave side tready according to tready_probability
  duty_cycle_p : process(clk, rst)
    variable rand : RandomPType;
  begin
    if rst = '1' then
      rand.InitSeed("duty_cycle_p" & integer'image(SEED) & time'image(now));
      s_tready <= '0';
    elsif rising_edge(clk) then
      s_tready <= '0';
      if rand.RandReal(1.0) < tready_probability then
        s_tready <= '1';
      end if;
    end if;
  end process;

end axi_stream_width_converter_tb;

-- vim: set foldmethod=marker foldmarker=--\ {{,--\ }} :
