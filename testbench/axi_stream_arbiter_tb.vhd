--
-- FPGA core library
--
-- Copyright 2020-2022 by Andre Souto (suoto)
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

entity axi_stream_arbiter_tb is
  generic (
    runner_cfg      : string;
    REGISTER_INPUTS : boolean;
    MODE            : string   := ""; -- ROUND_ROBIN, INTERLEAVED, ABSOLUTE
    SEED            : integer
  );
end axi_stream_arbiter_tb;

architecture axi_stream_arbiter_tb of axi_stream_arbiter_tb is

  constant CLK_PERIOD        : time := 5 ns;
  constant INTERFACES        : positive := 4;
  constant DATA_WIDTH        : integer := 8;

  signal clk                : std_logic := '0';
  signal rst                : std_logic;

  signal selected           : std_logic_vector(INTERFACES - 1 downto 0);
  signal selected_encoded   : std_logic_vector(numbits(INTERFACES) - 1 downto 0);

  signal m_axi0             : axi_stream_data_bus_t(tdata(DATA_WIDTH - 1 downto 0));
  signal m_axi1             : axi_stream_data_bus_t(tdata(DATA_WIDTH - 1 downto 0));
  signal m_axi2             : axi_stream_data_bus_t(tdata(DATA_WIDTH - 1 downto 0));
  signal m_axi3             : axi_stream_data_bus_t(tdata(DATA_WIDTH - 1 downto 0));

  signal s_axi              : axi_stream_data_bus_t(tdata(DATA_WIDTH - 1 downto 0));

  signal cfg_rd_probability : real := 1.0;

begin

  -------------------
  -- Port mappings --
  -------------------
  axi_master_0_bfm_u : entity fpga_cores_sim.axi_stream_bfm
    generic map (
      NAME        => "axi_master_0_bfm_u",
      TDATA_WIDTH => DATA_WIDTH,
      SEED        => SEED)
    port map (
      -- Usual ports
      clk        => clk,
      rst        => rst,
      -- AXI stream output
      m_tready   => m_axi0.tready,
      m_tdata    => m_axi0.tdata,
      m_tvalid   => m_axi0.tvalid,
      m_tlast    => m_axi0.tlast);

  axi_master_1_bfm_u : entity fpga_cores_sim.axi_stream_bfm
    generic map (
      NAME        => "axi_master_1_bfm_u",
      TDATA_WIDTH => DATA_WIDTH,
      SEED        => SEED)
    port map (
      -- Usual ports
      clk        => clk,
      rst        => rst,
      -- AXI stream output
      m_tready   => m_axi1.tready,
      m_tdata    => m_axi1.tdata,
      m_tvalid   => m_axi1.tvalid,
      m_tlast    => m_axi1.tlast);

  axi_master_2_bfm_u : entity fpga_cores_sim.axi_stream_bfm
    generic map (
      NAME        => "axi_master_2_bfm_u",
      TDATA_WIDTH => DATA_WIDTH,
      SEED        => SEED)
    port map (
      -- Usual ports
      clk        => clk,
      rst        => rst,
      -- AXI stream output
      m_tready   => m_axi2.tready,
      m_tdata    => m_axi2.tdata,
      m_tvalid   => m_axi2.tvalid,
      m_tlast    => m_axi2.tlast);

  axi_master_3_bfm_u : entity fpga_cores_sim.axi_stream_bfm
    generic map (
      NAME        => "axi_master_3_bfm_u",
      TDATA_WIDTH => DATA_WIDTH,
      SEED        => SEED)
    port map (
      -- Usual ports
      clk        => clk,
      rst        => rst,
      -- AXI stream output
      m_tready   => m_axi3.tready,
      m_tdata    => m_axi3.tdata,
      m_tvalid   => m_axi3.tvalid,
      m_tlast    => m_axi3.tlast);

  dut : entity fpga_cores.axi_stream_arbiter
    generic map (
      MODE            => MODE,
      INTERFACES      => INTERFACES,
      DATA_WIDTH      => DATA_WIDTH,
      REGISTER_INPUTS => REGISTER_INPUTS)
    port map (
      -- Write port
      clk              => clk,
      rst              => rst,

      selected         => selected,
      selected_encoded => selected_encoded,

      s_tvalid(3)      => m_axi3.tvalid,
      s_tvalid(2)      => m_axi2.tvalid,
      s_tvalid(1)      => m_axi1.tvalid,
      s_tvalid(0)      => m_axi0.tvalid,

      s_tready(3)      => m_axi3.tready,
      s_tready(2)      => m_axi2.tready,
      s_tready(1)      => m_axi1.tready,
      s_tready(0)      => m_axi0.tready,

      s_tdata(3)       => m_axi3.tdata,
      s_tdata(2)       => m_axi2.tdata,
      s_tdata(1)       => m_axi1.tdata,
      s_tdata(0)       => m_axi0.tdata,

      s_tlast(3)       => m_axi3.tlast,
      s_tlast(2)       => m_axi2.tlast,
      s_tlast(1)       => m_axi1.tlast,
      s_tlast(0)       => m_axi0.tlast,

      m_tvalid         => s_axi.tvalid,
      m_tready         => s_axi.tready,
      m_tdata          => s_axi.tdata,
      m_tlast          => s_axi.tlast);


  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  clk <= not clk after CLK_PERIOD/2;

  test_runner_watchdog(runner, 20 us);

  ---------------
  -- Processes --
  ---------------
  main : process
    constant self        : actor_t  := new_actor("main");
    constant checker     : actor_t  := new_actor("checker");
    constant logger      : logger_t := get_logger("main");
    variable axi_master0 : axi_stream_bfm_t := create_bfm("axi_master_0_bfm_u");
    variable axi_master1 : axi_stream_bfm_t := create_bfm("axi_master_1_bfm_u");
    variable axi_master2 : axi_stream_bfm_t := create_bfm("axi_master_2_bfm_u");
    variable axi_master3 : axi_stream_bfm_t := create_bfm("axi_master_3_bfm_u");
    --
    procedure walk (constant steps : natural := 1) is
    begin
      if steps /= 0 then
        for step in 0 to steps - 1 loop
          wait until rising_edge(clk);
        end loop;
      end if;
    end procedure;

    impure function generate_frame ( constant first_value : std_logic_vector; constant length : integer) return std_logic_array_t is
      variable frame : std_logic_array_t(0 to length - 1)(DATA_WIDTH - 1 downto 0);
    begin
      frame(0) := first_value;
      for i in 1 to length - 1 loop
        frame(i) := std_logic_vector(unsigned(frame(i - 1)) + 1);
      end loop;
      return frame;
    end;

    procedure test_round_robin_base_sequence ( constant frames_per_interface : positive ) is
      variable msg      : msg_t;
      variable expected : std_logic_array_t(0 to INTERFACES*frames_per_interface - 1)(DATA_WIDTH downto 0);
      variable received : std_logic_vector(DATA_WIDTH downto 0);
    begin
      cfg_rd_probability <= 1.0;

      for i in 0 to frames_per_interface - 1 loop
        axi_bfm_write(net,
          bfm         => axi_master0,
          data        => generate_frame(first_value => x"0" & std_logic_vector(to_unsigned(4*i, 4)), length => 1),
          blocking    => False);

        axi_bfm_write(net,
          bfm         => axi_master1,
          data        => generate_frame(first_value => x"1" & std_logic_vector(to_unsigned(4*i, 4)), length => 1),
          blocking    => False);

        axi_bfm_write(net,
          bfm         => axi_master2,
          data        => generate_frame(first_value => x"2" & std_logic_vector(to_unsigned(4*i, 4)), length => 1),
          blocking    => False);

        axi_bfm_write(net,
          bfm         => axi_master3,
          data        => generate_frame(first_value => x"3" & std_logic_vector(to_unsigned(4*i, 4)), length => 1),
          blocking    => False);

        expected(4*i)     := '1' & x"0" & std_logic_vector(to_unsigned(4*i, 4));
        expected(4*i + 1) := '1' & x"1" & std_logic_vector(to_unsigned(4*i, 4));
        expected(4*i + 2) := '1' & x"2" & std_logic_vector(to_unsigned(4*i, 4));
        expected(4*i + 3) := '1' & x"3" & std_logic_vector(to_unsigned(4*i, 4));
      end loop;

      for i in expected'range loop
        receive(net, self, msg);
        received := pop(msg);
        check_equal(
          received,
          expected(i),
          sformat("Word %d: expected %r but got %r", fo(i), fo(expected(i)), fo(received)));
      end loop;
    end;

    procedure test_round_robin_arb_sequence_0 is
      variable msg      : msg_t;
      constant expected : std_logic_array_t(0 to 7)(DATA_WIDTH downto 0) := (
        '0' & x"10", '1' & x"11",
        '0' & x"20", '1' & x"21",
        '0' & x"30", '1' & x"31",
        '0' & x"00", '1' & x"01");
      variable received : std_logic_vector(DATA_WIDTH downto 0);
    begin
      axi_bfm_write(net,
        bfm         => axi_master2,
        data        => generate_frame(first_value => x"20", length => 2),
        blocking    => False);
      axi_bfm_write(net,
        bfm         => axi_master1,
        data        => generate_frame(first_value => x"10", length => 2),
        blocking    => False);
      axi_bfm_write(net,
        bfm         => axi_master3,
        data        => generate_frame(first_value => x"30", length => 2),
        blocking    => False);

      walk(2); cfg_rd_probability <= 1.0; walk(2);

      axi_bfm_write(net,
        bfm         => axi_master0,
        data        => generate_frame(first_value => x"00", length => 2),
        blocking    => False);

      for i in expected'range loop
        receive(net, self, msg);
        received := pop(msg);
        check_equal(
          received,
          expected(i),
          sformat("Word %d: expected %r but got %r", fo(i), fo(expected(i)), fo(received)));
      end loop;
    end;

    procedure test_round_robin_arb_sequence_1 is
      variable msg      : msg_t;
      constant expected : std_logic_array_t(0 to 7)(DATA_WIDTH downto 0) := (
        '0' & x"20", '0' & x"21", '0' & x"22", '1' & x"23",
        '1' & x"00",
        '1' & x"10",
        '1' & x"24",
        '1' & x"30");
      variable received : std_logic_vector(DATA_WIDTH downto 0);
      variable errors   : integer := 0;
    begin
      axi_bfm_write(net,
        bfm         => axi_master2,
        data        => generate_frame(first_value => x"20", length => 4),
        blocking    => False);
      axi_bfm_write(net,
        bfm         => axi_master2,
        data        => generate_frame(first_value => x"24", length => 1),
        blocking    => False);

      cfg_rd_probability <= 1.0;
      walk(3);

      axi_bfm_write(net,
        bfm         => axi_master0,
        data        => generate_frame(first_value => x"00", length => 1),
        blocking    => False);
      axi_bfm_write(net,
        bfm         => axi_master1,
        data        => generate_frame(first_value => x"10", length => 1),
        blocking    => False);
      axi_bfm_write(net,
        bfm         => axi_master3,
        data        => generate_frame(first_value => x"30", length => 1),
        blocking    => False);

      for i in expected'range loop
        receive(net, self, msg);
        received := pop(msg);
        check_equal(
          received,
          expected(i),
          sformat("Word %d: expected %r but got %r", fo(i), fo(expected(i)), fo(received)));
      end loop;
    end;

    procedure test_round_robin_multiple_frames ( constant rd_probability : real ) is
      variable msg      : msg_t;
      constant expected : std_logic_array_t(0 to 31)(DATA_WIDTH downto 0) := (
        '0' & x"00", '0' & x"01", '0' & x"02", '1' & x"03",
        '0' & x"10", '0' & x"11", '0' & x"12", '1' & x"13",
        '0' & x"20", '0' & x"21", '0' & x"22", '1' & x"23",
        '0' & x"30", '0' & x"31", '0' & x"32", '1' & x"33",

        '0' & x"04", '0' & x"05", '0' & x"06", '1' & x"07",
        '0' & x"14", '0' & x"15", '0' & x"16", '1' & x"17",
        '0' & x"24", '0' & x"25", '0' & x"26", '1' & x"27",
        '0' & x"34", '0' & x"35", '0' & x"36", '1' & x"37");

      variable received : std_logic_vector(DATA_WIDTH downto 0);
    begin
      axi_bfm_write(net,
        bfm         => axi_master0,
        data        => generate_frame(first_value => x"00", length => 4),
        blocking    => False);
      axi_bfm_write(net,
        bfm         => axi_master0,
        data        => generate_frame(first_value => x"04", length => 4),
        blocking    => False);

      axi_bfm_write(net,
        bfm         => axi_master1,
        data        => generate_frame(first_value => x"10", length => 4),
        blocking    => False);
      axi_bfm_write(net,
        bfm         => axi_master1,
        data        => generate_frame(first_value => x"14", length => 4),
        blocking    => False);

      axi_bfm_write(net,
        bfm         => axi_master2,
        data        => generate_frame(first_value => x"20", length => 4),
        blocking    => False);
      axi_bfm_write(net,
        bfm         => axi_master2,
        data        => generate_frame(first_value => x"24", length => 4),
        blocking    => False);

      axi_bfm_write(net,
        bfm         => axi_master3,
        data        => generate_frame(first_value => x"30", length => 4),
        blocking    => False);
      axi_bfm_write(net,
        bfm         => axi_master3,
        data        => generate_frame(first_value => x"34", length => 4),
        blocking    => False);

      cfg_rd_probability <= rd_probability;

      for i in expected'range loop
        receive(net, self, msg);
        received := pop(msg);
        check_equal(
          received,
          expected(i),
          sformat("Word %d: expected %r but got %r", fo(i), fo(expected(i)), fo(received)));
      end loop;
    end;

    procedure test_round_robin_uneven_rates ( constant rd_probability : real ) is
      variable msg      : msg_t;
      constant expected : std_logic_array_t(0 to 9)(DATA_WIDTH downto 0) := (
        '1' & x"10",
        '0' & x"20", '0' & x"21", '0' & x"22", '1' & x"23",
        '1' & x"30",
        '0' & x"24", '0' & x"25", '0' & x"26", '1' & x"27");

      variable received : std_logic_vector(DATA_WIDTH downto 0);
    begin
      axi_bfm_write(net,
        bfm         => axi_master1,
        data        => generate_frame(first_value => x"10", length => 1),
        blocking    => False);
      axi_bfm_write(net,
        bfm         => axi_master2,
        data        => generate_frame(first_value => x"20", length => 4),
        blocking    => False);
      axi_bfm_write(net,
        bfm         => axi_master2,
        data        => generate_frame(first_value => x"24", length => 4),
        blocking    => False);
      axi_bfm_write(net,
        bfm         => axi_master3,
        data        => generate_frame(first_value => x"30", length => 1),
        blocking    => False);

      cfg_rd_probability <= rd_probability;

      for i in expected'range loop
        receive(net, self, msg);
        received := pop(msg);
        check_equal(
          received,
          expected(i),
          sformat("Word %d: expected %r but got %r", fo(i), fo(expected(i)), fo(received)));
      end loop;
    end;

    procedure test_interleaved_0 is
      variable msg      : msg_t;
      constant expected : std_logic_array_t(0 to 15)(DATA_WIDTH downto 0) := (
        '0' & x"00", '0' & x"01", '0' & x"02", '1' & x"03",
        '0' & x"10", '0' & x"11", '0' & x"12", '1' & x"13",
        '0' & x"20", '0' & x"21", '0' & x"22", '1' & x"23",
        '0' & x"30", '0' & x"31", '0' & x"32", '1' & x"33");
      variable received : std_logic_vector(DATA_WIDTH downto 0);
    begin
      axi_bfm_write(net,
        bfm         => axi_master0,
        data        => generate_frame(first_value => x"00", length => 4),
        blocking    => False);
      -- Let the first transfer start then send the next ones out of order
      cfg_rd_probability <= 1.0;
      walk(2);

      axi_bfm_write(net,
        bfm         => axi_master2,
        data        => generate_frame(first_value => x"20", length => 4),
        blocking    => False);
      axi_bfm_write(net,
        bfm         => axi_master3,
        data        => generate_frame(first_value => x"30", length => 4),
        blocking    => False);
      axi_bfm_write(net,
        bfm         => axi_master1,
        data        => generate_frame(first_value => x"10", length => 4),
        blocking    => False);

      for i in expected'range loop
        receive(net, self, msg);
        received := pop(msg);
        check_equal(
          received,
          expected(i),
          sformat("Word %d: expected %r but got %r", fo(i), fo(expected(i)), fo(received)));
      end loop;
    end;

    procedure test_interleaved_1 is
      variable msg      : msg_t;
      constant expected : std_logic_array_t(0 to 15)(DATA_WIDTH downto 0) := (
        '0' & x"00", '0' & x"01", '0' & x"02", '1' & x"03",
        '0' & x"10", '0' & x"11", '0' & x"12", '1' & x"13",
        '0' & x"20", '0' & x"21", '0' & x"22", '1' & x"23",
        '0' & x"30", '0' & x"31", '0' & x"32", '1' & x"33");
      variable received : std_logic_vector(DATA_WIDTH downto 0);
    begin
      cfg_rd_probability <= 1.0;

      walk(2);
      axi_bfm_write(net,
        bfm         => axi_master3,
        data        => generate_frame(first_value => x"30", length => 4),
        blocking    => False);

      walk(2);
      axi_bfm_write(net,
        bfm         => axi_master2,
        data        => generate_frame(first_value => x"20", length => 4),
        blocking    => False);

      walk(2);
      axi_bfm_write(net,
        bfm         => axi_master1,
        data        => generate_frame(first_value => x"10", length => 4),
        blocking    => False);

      walk(2);
      axi_bfm_write(net,
        bfm         => axi_master0,
        data        => generate_frame(first_value => x"00", length => 4),
        blocking    => False);

      for i in expected'range loop
        receive(net, self, msg);
        received := pop(msg);
        check_equal(
          received,
          expected(i),
          sformat("Word %d: expected %r but got %r", fo(i), fo(expected(i)), fo(received)));
      end loop;
    end;

    procedure test_absolute_0 is
      variable msg      : msg_t;
      constant expected : std_logic_array_t(0 to 15)(DATA_WIDTH downto 0) := (
        '0' & x"00", '0' & x"01", '0' & x"02", '1' & x"03",
        '0' & x"10", '0' & x"11", '0' & x"12", '1' & x"13",
        '0' & x"20", '0' & x"21", '0' & x"22", '1' & x"23",
        '0' & x"30", '0' & x"31", '0' & x"32", '1' & x"33");
      variable received : std_logic_vector(DATA_WIDTH downto 0);
    begin
      cfg_rd_probability <= 1.0;

      axi_bfm_write(net,
        bfm         => axi_master0,
        data        => generate_frame(first_value => x"00", length => 4),
        blocking    => False);
      axi_bfm_write(net,
        bfm         => axi_master1,
        data        => generate_frame(first_value => x"10", length => 4),
        blocking    => False);
      axi_bfm_write(net,
        bfm         => axi_master2,
        data        => generate_frame(first_value => x"20", length => 4),
        blocking    => False);
      axi_bfm_write(net,
        bfm         => axi_master3,
        data        => generate_frame(first_value => x"30", length => 4),
        blocking    => False);

      for i in expected'range loop
        receive(net, self, msg);
        received := pop(msg);
        check_equal(
          received,
          expected(i),
          sformat("Word %d: expected %r but got %r", fo(i), fo(expected(i)), fo(received)));
      end loop;
    end;

    procedure test_absolute_1 is
      variable msg      : msg_t;
      constant expected : std_logic_array_t(0 to 15)(DATA_WIDTH downto 0) := (
        '0' & x"20", '0' & x"21", '0' & x"22", '1' & x"23",
        '0' & x"00", '0' & x"01", '0' & x"02", '1' & x"03",
        '0' & x"10", '0' & x"11", '0' & x"12", '1' & x"13",
        '0' & x"30", '0' & x"31", '0' & x"32", '1' & x"33");
      variable received : std_logic_vector(DATA_WIDTH downto 0);
    begin
      cfg_rd_probability <= 1.0;

      axi_bfm_write(net,
        bfm         => axi_master2,
        data        => generate_frame(first_value => x"20", length => 4),
        blocking    => False);
      axi_bfm_write(net,
        bfm         => axi_master3,
        data        => generate_frame(first_value => x"30", length => 4),
        blocking    => False);
      walk(2);
      axi_bfm_write(net,
        bfm         => axi_master1,
        data        => generate_frame(first_value => x"10", length => 4),
        blocking    => False);
      walk(2);
      axi_bfm_write(net,
        bfm         => axi_master0,
        data        => generate_frame(first_value => x"00", length => 4),
        blocking    => False);

      for i in expected'range loop
        receive(net, self, msg);
        received := pop(msg);
        check_equal(
          received,
          expected(i),
          sformat("Word %d: expected %r but got %r", fo(i), fo(expected(i)), fo(received)));
      end loop;
    end;

    procedure test_absolute_2 is
      variable msg      : msg_t;
      constant expected : std_logic_array_t(0 to 23)(DATA_WIDTH downto 0) := (
        '0' & x"20", '0' & x"21", '0' & x"22", '1' & x"23",
        '0' & x"24", '0' & x"25", '0' & x"26", '1' & x"27",
        '0' & x"30", '0' & x"31", '0' & x"32", '1' & x"33",
        '0' & x"34", '0' & x"35", '0' & x"36", '1' & x"37",
        '0' & x"00", '0' & x"01", '0' & x"02", '1' & x"03",
        '0' & x"10", '0' & x"11", '0' & x"12", '1' & x"13"
      );
      variable received : std_logic_vector(DATA_WIDTH downto 0);
    begin
      cfg_rd_probability <= 1.0;

      axi_bfm_write(net,
        bfm         => axi_master2,
        data        => generate_frame(first_value => x"20", length => 4),
        blocking    => False);
      axi_bfm_write(net,
        bfm         => axi_master2,
        data        => generate_frame(first_value => x"24", length => 4),
        blocking    => False);
      axi_bfm_write(net,
        bfm         => axi_master3,
        data        => generate_frame(first_value => x"30", length => 4),
        blocking    => False);
      axi_bfm_write(net,
        bfm         => axi_master3,
        data        => generate_frame(first_value => x"34", length => 4),
        blocking    => False);
      walk(15);

      axi_bfm_write(net,
        bfm         => axi_master1,
        data        => generate_frame(first_value => x"10", length => 4),
        blocking    => False);
      axi_bfm_write(net,
        bfm         => axi_master0,
        data        => generate_frame(first_value => x"00", length => 4),
        blocking    => False);

      for i in expected'range loop
        receive(net, self, msg);
        received := pop(msg);
        check_equal(
          received,
          expected(i),
          sformat("Word %d: expected %r but got %r", fo(i), fo(expected(i)), fo(received)));
      end loop;
    end;

    --
    variable stat   : checker_stat_t;
  begin

    show(display_handler, debug);
    show(display_handler, trace);
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      cfg_rd_probability <= 0.0;

      rst <= '1';
      walk(16);
      rst <= '0';
      walk(16);

      set_timeout(runner, 2 us);

      info(logger, "Running '" & active_test_case & "'");
      if run("test_round_robin_base_sequence") then
        test_round_robin_base_sequence(frames_per_interface => 4);
      elsif run("test_round_robin_arb_sequence_0") then
        test_round_robin_arb_sequence_0;
      elsif run("test_round_robin_arb_sequence_1") then
        test_round_robin_arb_sequence_1;
      elsif run("test_round_robin_multiple_frames_100") then
        test_round_robin_multiple_frames(1.0);
      elsif run("test_round_robin_multiple_frames_50") then
        test_round_robin_multiple_frames(0.5);
      elsif run("test_round_robin_multiple_frames_20") then
        test_round_robin_multiple_frames(0.2);
      elsif run("test_round_robin_uneven_rates_100") then
        cfg_rd_probability <= 1.0;
        walk(1);
        test_round_robin_base_sequence(frames_per_interface => 1);
        test_round_robin_uneven_rates(1.0);
        test_round_robin_base_sequence(frames_per_interface => 1);
      elsif run("test_round_robin_uneven_rates_20") then
        test_round_robin_uneven_rates(0.2);

      elsif run("test_interleaved_0") then
        test_interleaved_0;
      elsif run("test_interleaved_1") then
        test_interleaved_1;
      elsif run("test_absolute_0") then
        test_absolute_0;
      elsif run("test_absolute_1") then
        test_absolute_1;
      elsif run("test_absolute_2") then
        test_absolute_2;
      end if;

      join(net, axi_master0);
      join(net, axi_master1);
      join(net, axi_master2);
      join(net, axi_master3);

      walk(16);

      if has_message(self) then
        failure("There should not be any messages from the receiver by now");
      end if;

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

  begin

    wait until rst = '0';

    while True loop
      wait until s_axi.tvalid = '1' and s_axi.tready = '1' and rising_edge(clk);
      msg := new_msg;
      push(msg, s_axi.tlast & s_axi.tdata);
      send(net, main, msg);

      word_count := word_count + 1;

      if s_axi.tlast = '1' then
        debug(logger, sformat("End of frame %d detected at word %d", fo(frame_count), fo(word_count)));
        frame_count := frame_count + 1;
        word_count  := 0;
      end if;
    end loop;

    wait;
  end process;

  rd_en_randomize : process
    variable random_gen : RandomPType;
  begin
    s_axi.tready <= '0';
    random_gen.InitSeed("rd_en_randomize" & integer'image(SEED) & time'image(now));
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

end axi_stream_arbiter_tb;
