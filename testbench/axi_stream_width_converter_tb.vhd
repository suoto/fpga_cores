--
-- DVB FPGA
--
-- Copyright 2019 by Suoto <andre820@gmail.com>
--
-- This file is part of DVB FPGA.
--
-- DVB FPGA is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- DVB FPGA is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with DVB FPGA.  If not, see <http://www.gnu.org/licenses/>.

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
use fpga_cores_sim.testbench_utils_pkg.all;
use fpga_cores_sim.axi_stream_bfm_pkg.all;

entity axi_stream_width_converter_tb is
  generic (
    RUNNER_CFG        : string;
    INPUT_DATA_WIDTH  : natural := 24;
    OUTPUT_DATA_WIDTH : natural := 16);
end axi_stream_width_converter_tb;

architecture axi_stream_width_converter_tb of axi_stream_width_converter_tb is

  impure function reinterpret ( constant v : std_logic_vector_2d_t; constant width : natural ) return std_logic_vector_2d_t is
    constant in_length  : natural := v'length;
    constant in_width   : natural := v(v'low)'length;
    constant out_length : natural := (in_length * in_width + width - 1) / width;
    variable result     : std_logic_vector_2d_t(0 to out_length - 1)(width - 1 downto 0);
    variable bit_cnt    : natural := 0;
    variable ptr        : natural := 0;
    variable tmp        : std_logic_vector(in_width + width - 1 downto 0);
  begin
    info(sformat("Converting %d x %d => %d x %d", fo(in_length), fo(in_width), fo(out_length), fo(width)));

    for i in v'range loop
      tmp(in_width + bit_cnt - 1 downto bit_cnt) := v(i);
      bit_cnt                                    := bit_cnt + in_width;

      while bit_cnt >= width loop
        result(ptr) := tmp(width - 1 downto 0);
        tmp         := (width - 1 downto 0 => 'U') & tmp(tmp'length - 1 downto width);
        bit_cnt     := bit_cnt - width;
        ptr         := ptr + 1;

      end loop;
    end loop;

    return result;
  end;

  ---------------
  -- Constants --
  ---------------
  constant CLK_PERIOD        : time := 5 ns;
  constant ERROR_CNT_WIDTH   : natural := 8;
  constant INPUT_BYTE_WIDTH  : natural := (INPUT_DATA_WIDTH + 7) / 8;
  constant OUTPUT_BYTE_WIDTH : natural := (OUTPUT_DATA_WIDTH + 7) / 8;
  constant AXI_TID_WIDTH     : natural := 8;

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
      INPUT_DATA_WIDTH  => INPUT_DATA_WIDTH,
      OUTPUT_DATA_WIDTH => OUTPUT_DATA_WIDTH)
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
      DATA_WIDTH => INPUT_DATA_WIDTH,
      ID_WIDTH   => AXI_TID_WIDTH)
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

  test_runner_watchdog(runner, 200 us);

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
    procedure send_frame ( constant frame : axi_stream_frame_t ) is
      variable msg : msg_t := new_msg(sender => self);
    begin
      info("Sending frame");
      push(msg, frame);
      send(net, find("checker_p"), msg);
    end;

    ------------------------------------------------------------------------------------
    procedure test_frame ( constant id   : std_logic_vector(AXI_TID_WIDTH - 1 downto 0);
                           constant data : byte_array_t ) is

      constant frame : axi_stream_frame_t := (data, id, tready_probability);
    begin
      info(sformat("Writing frame: id=%r, data=%s" & cr, fo(id), to_string(data)));

      send_frame(frame);

      bfm_write(net,
        bfm         => master,
        data        => data,
        id          => id,
        probability => tvalid_probability,
        blocking    => True);

    end;

    ------------------------------------------------------------------------------------
    procedure run_test ( constant frames : positive ) is
    begin
      for i in 0 to 255 loop
        test_frame(
          id => rand.RandSlv(AXI_TID_WIDTH),
          data => random(rand.RandInt(INPUT_BYTE_WIDTH*OUTPUT_BYTE_WIDTH) + 1)
        );
      end loop;
    end;
    ------------------------------------------------------------------------------------


  begin
    rand.InitSeed("some_seed");

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
        run_test(256);

      elsif run("slow_master") then
        tvalid_probability <= 0.5;
        tready_probability <= 1.0;
        run_test(256);

      elsif run("slow_slave") then
        tvalid_probability <= 1.0;
        tready_probability <= 0.5;
        run_test(256);

      elsif run("slow_master_and_slave") then
        tvalid_probability <= 0.75;
        tready_probability <= 0.75;
        run_test(256);

      elsif run("test_partial_words") then

        for i in 0 to 255 loop
          for base_width in 0 to max(INPUT_BYTE_WIDTH, OUTPUT_BYTE_WIDTH) - 1 loop
            test_frame(
              id => rand.RandSlv(AXI_TID_WIDTH),
              data => random(base_width + 1)
            );
          end loop;
        end loop;

      end if;

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
    procedure check_frame ( constant frame : axi_stream_frame_t ) is
      variable exp_tdata : std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);
      variable exp_tkeep : std_logic_vector(OUTPUT_BYTE_WIDTH - 1 downto 0);
      variable byte      : natural;
      variable word_cnt  : natural := 0;
      variable failed    : boolean := False;

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

      end;

    begin

      info(sformat("Checking frame: id=%r, data=%s" & cr, fo(frame.id), to_string(frame.data)));

      for i in 0 to frame.data'length - 1 loop
        byte := i mod OUTPUT_BYTE_WIDTH;

        exp_tdata(8*(byte + 1) - 1 downto 8*byte) := frame.data(i);

        if ((i + 1) mod OUTPUT_BYTE_WIDTH) = 0 then
          if i /= frame.data'length - 1 then
            check_word(exp_tdata, (others => '0'), frame.id, False);
          else
            check_word(exp_tdata, (others => '1'), frame.id, True);
          end if;

          exp_tdata := (others => 'U');
          word_cnt  := word_cnt + 1;
        end if;
      end loop;

      if byte = 1 then
        return;
      end if;

      exp_tkeep                := (others => '0');
      exp_tkeep(byte downto 0) := (others => '1');

      check_word(exp_tdata, exp_tkeep, frame.id, True);
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
