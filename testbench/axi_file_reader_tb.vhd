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

---------------
-- Libraries --
---------------
use std.textio.all;

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
use fpga_cores_sim.file_utils_pkg.all;
use fpga_cores_sim.testbench_utils_pkg.all;

------------------------
-- Entity declaration --
------------------------
entity axi_file_reader_tb is
  generic (
    runner_cfg : string;
    DATA_WIDTH : integer;
    test_cfg   : string);
end axi_file_reader_tb;

architecture axi_file_reader_tb of axi_file_reader_tb is

  type config_t is record
    input_file     : line;
    reference_file : line;
  end record;

  type config_ptr_t is access config_t;
  type config_array_t is array (natural range <>) of config_t;
  type config_array_ptr_t is access config_array_t;

  impure function decode_line (
    constant s     : in string) return config_t is
    constant div_0 : integer := find(s, ",");
    variable div_1 : integer := find(s, ",", start => div_0 + 1);
  begin
    if div_1 = 0 then
      div_1 := s'length + 1;
    end if;

    debug(sformat("div_0=%d, div_1=%d", fo(div_0), fo(div_1)));

    return (
      input_file => new string'(s(1 to div_0 - 1)),
      reference_file => new string'(s(div_0 + 1 to div_1 - 1))
    );
  end function;

  impure function get_config (
    constant s        : in string) return config_array_t is
    constant num_cfgs : integer := count(s, "|") + 1;
    variable cfg_list : config_array_t(0 to num_cfgs - 1);
    variable lines    : lines_t := split(s, "|");
  begin

    for i in lines'range loop
      info(sformat("%d => decoding '%s'", fo(i), lines(i).all));
      cfg_list(i) := decode_line(lines(i).all);
      debug(sformat("cfg_list(%d) = {input_file: '%s', reference_file: '%s'}", fo(i), cfg_list(i).input_file.all, cfg_list(i).reference_file.all));
    end loop;

    return cfg_list;
  end;


  ---------------
  -- Constants --
  ---------------
  constant READER_NAME : string := "dut";
  constant CLK_PERIOD  : time := 5 ns;

  -------------
  -- Signals --
  -------------
  signal clk                : std_logic := '0';
  signal rst                : std_logic;
  signal completed          : std_logic;
  signal s_tready           : std_logic;
  signal s_tdata            : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal s_tkeep            : std_logic_vector(DATA_WIDTH/8 - 1 downto 0);
  signal s_tvalid           : std_logic;
  signal s_tlast            : std_logic;

  signal tvalid_probability : real range 0.0 to 1.0 := 1.0;
  signal tready_probability : real range 0.0 to 1.0 := 1.0;

begin

  -------------------
  -- Port mappings --
  -------------------
  dut : entity fpga_cores_sim.axi_file_reader
    generic map (
      READER_NAME    => READER_NAME,
      DATA_WIDTH     => DATA_WIDTH)
    port map (
      -- Usual ports
      clk                => clk,
      rst                => rst,
      -- Config and status
      completed          => completed,
      tvalid_probability => tvalid_probability,
      -- Data output
      m_tready           => s_tready,
      m_tdata            => s_tdata,
      m_tkeep            => s_tkeep,
      m_tvalid           => s_tvalid,
      m_tlast            => s_tlast);

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  clk <= not clk after CLK_PERIOD/2;
  test_runner_watchdog(runner, 2 ms);

  ---------------
  -- Processes --
  ---------------
  main : process

    variable config_list : config_array_ptr_t;
    variable file_reader : file_reader_t := new_file_reader(READER_NAME);
    constant check_p     : actor_t := find("check_p");

    procedure walk(constant steps : natural) is
    begin
      if steps /= 0 then
        for step in 0 to steps - 1 loop
          wait until rising_edge(clk);
        end loop;
      end if;
    end procedure walk;
    ------------------------------------------------------------------------------------

    procedure run_test is
      variable cfg : config_ptr_t;
      variable msg : msg_t;
    begin
      for i in config_list'range loop
        cfg := new config_t'(config_list(i));
        -- Notify the DUT
        read_file(net, file_reader, cfg.input_file.all);
        -- Notify the TB check process
        msg := new_msg;
        push(msg, cfg.reference_file.all);
        send(net, check_p, msg);
      end loop;

      info("Notifications sent, waiting for files to be read");
      wait_all_read(net, file_reader);
      -- info("All read, now waiting for s_tvalid and s_tready and s_tlast");
      -- wait until s_tvalid = '1' and s_tready = '1' and s_tlast = '1' and rising_edge(clk);
      info("All files have now been read");
    end procedure run_test;
    ------------------------------------------------------------------------------------

    procedure test_tvalid_probability is
      variable start          : time;
      variable baseline       : integer;
      variable tvalid_half    : integer;
      variable tvalid_quarter : integer;
      variable result         : real;
    begin
      rst <= '1'; walk(4); rst <= '0';
      tvalid_probability <= 1.0;
      start := now;
      for i in 0 to 9 loop
        run_test;
      end loop;
      baseline := (now - start) / CLK_PERIOD / 10;

      rst <= '1'; walk(4); rst <= '0';
      tvalid_probability <= 0.5;
      start := now;
      for i in 0 to 9 loop
        run_test;
      end loop;
      tvalid_half := (now - start) / CLK_PERIOD / 10;

      rst <= '1'; walk(4); rst <= '0';
      tvalid_probability <= 0.25;
      start := now;
      for i in 0 to 9 loop
        run_test;
      end loop;
      tvalid_quarter := (now - start) / CLK_PERIOD / 10;

      -- Check time taken is the expected +/- 10%
      info(sformat("baseline=%d, half=%d (%d), quarter=%d (%d)",
                   fo(baseline), fo(tvalid_half), fo(tvalid_half/2),
                   fo(tvalid_quarter), fo(tvalid_quarter/4)));

      -- Check that time taken is what we expect with a 20% margin
      result := real(tvalid_half) / 2.0 / real(baseline);
      check_true(result > 0.85, sformat("Value of %s is below 25\% tolerance for probability=0.5", real'image(result)));
      check_true(result < 1.15, sformat("Value of %s is above 25\% tolerance for probability=0.5", real'image(result)));

      result := real(tvalid_quarter) / 4.0 / real(baseline);
      check_true(result > 0.85, sformat("Value of %s is below 25\% tolerance for probability=0.25", real'image(result)));
      check_true(result < 1.15, sformat("Value of %s is above 25\% tolerance for probability=0.25", real'image(result)));

    end procedure test_tvalid_probability;
    ------------------------------------------------------------------------------------


  begin

    test_runner_setup(runner, runner_cfg);
    show(display_handler, (trace, debug));
    hide(get_logger("vunit_lib:com"), display_handler, Trace, True);

    -- Extract the config
    config_list := new config_array_t'(get_config(test_cfg));

    while test_suite loop
      tvalid_probability <= 1.0;
      tready_probability <= 1.0;

      rst <= '1';
      walk(4);
      rst <= '0';
      walk(4);

      if run("back_to_back") then
        warning("Running   back_to_back");
        tvalid_probability <= 1.0;
        tready_probability <= 1.0;
        run_test;
        warning("Completed back_to_back");

      elsif run("slow_read") then
        warning("Running   slow_read");
        tvalid_probability <= 1.0;
        tready_probability <= 0.5;
        run_test;
        warning("Completed slow_read");

      elsif run("slow_write") then
        warning("Running   slow_write");
        test_tvalid_probability;
        warning("Completed slow_write");

      end if;

      walk(4);

    end loop;

    test_runner_cleanup(runner);
    wait;

  end process main;

  -- Generate a tready enable with the configured probability
  s_tready_gen : process
    constant self           : actor_t := new_actor("check_p");
    variable tready_rand    : RandomPType;
    variable msg            : msg_t;
    variable word_cnt       : integer := 0;
    variable frame_cnt      : integer := 0;
    variable error_cnt      : integer := 0;
    variable expected_tdata : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    variable expected_tkeep : std_logic_vector(DATA_WIDTH/8 - 1 downto 0) := (others => '0');
    variable expected_tlast : std_logic;

    type file_status_t is (opened, closed, unknown);
    variable file_status : file_status_t := unknown;
    file file_handler    : text;
    variable L           : line;

    variable filename : line;
    variable lnum     : integer;

    procedure update_expected_values ( constant str : string ) is
      variable fields : lines_t := split(str, ",");
    begin
      -- trace("Updating values from '" & str & "'");
      hread(fields(0), expected_tdata);
      if DATA_WIDTH < 8 then
        expected_tkeep := (others => '1');
      else
        hread(fields(1), expected_tkeep);
      end if;
      read(fields(2), expected_tlast);

      debug(sformat("Updated expected values: L => '%s' || tdata=%r, tkeep=%r, tlast=%r || filename=%s:%d",
                    str, fo(expected_tdata), fo(expected_tkeep), fo(expected_tlast), filename.all, fo(lnum)));
      -- Mask off bytes that tkeep indicates are not valid. Those must be set to Xs
      if expected_tlast = '1' and DATA_WIDTH >= 8 then
        for byte in 0 to DATA_WIDTH/8 - 1 loop
          if expected_tkeep(byte) = '0' then
            expected_tdata(8*(byte + 1) - 1 downto 8*byte) := (others => 'U');
          end if;
        end loop;
      end if;
      debug(sformat("Updated expected values: L => '%s' || tdata=%r, tkeep=%r, tlast=%r || filename=%s:%d",
                    str, fo(expected_tdata), fo(expected_tkeep), fo(expected_tlast), filename.all, fo(lnum)));
    end procedure;

    variable failed : boolean := False;

  begin

    while True loop
      if rst = '1' and file_status = opened then
        info("Forcing file close due to reset");
        file_close(file_handler);
        file_status := closed;
      end if;

      s_tready <= '0';

      if file_status /= opened and has_message(self) then
        receive(net, self, msg);
        filename := new string'(pop(msg));
        info(sformat("Opening '%s'", filename.all));
        file_open(file_handler, filename.all, read_mode);
        lnum        := 0;
        file_status := opened;
      end if;

      if file_status = opened then
        if tready_rand.RandReal(1.0) <= tready_probability then
          s_tready <= '1';
        end if;
        if s_tready = '1' and s_tvalid = '1' then
          readline(file_handler, L);
          update_expected_values(L.all);
          lnum := lnum + 1;
          deallocate(L);

          if endfile(file_handler) then
            info(sformat("Closing '%s'", filename.all));
            file_close(file_handler);
            deallocate(filename);
            filename    := null;
            file_status := closed;
          end if;

          failed := False;
          if expected_tdata /= s_tdata then
            warning(sformat("Frame %d, word %d: TDATA error: Expected %r, got %r",
                            fo(frame_cnt), fo(word_cnt), fo(expected_tdata), fo(s_tdata)));
            failed    := True;
            error_cnt := error_cnt + 1;
          end if;

          if expected_tkeep /= s_tkeep then
            warning(sformat("Frame %d, word %d: Tkeep error: Expected %r, got %r",
                            fo(frame_cnt), fo(word_cnt), fo(expected_tkeep), fo(s_tkeep)));
            failed    := True;
            error_cnt := error_cnt + 1;
          end if;

          if expected_tlast /= s_tlast then
            warning(sformat("Frame %d, word %d: Tlast error: Expected %r, got %r",
                            fo(frame_cnt), fo(word_cnt), fo(expected_tlast), fo(s_tlast)));
            failed    := True;
            error_cnt := error_cnt + 1;
          end if;

          if failed then
            error("One or more checks failed");
          end if;

          if error_cnt > 10 then
            error("Too many errors");
          end if;

          if s_tlast = '1' then
            info(sformat("Received frame %d with %d words", fo(frame_cnt), fo(word_cnt)));
            frame_cnt := frame_cnt + 1;
            word_cnt  := 0;
          else
            word_cnt := word_cnt + 1;
          end if;
        end if;
      end if;

      wait until rising_edge(clk);
    end loop;
  end process;

end axi_file_reader_tb;
