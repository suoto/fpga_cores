--
-- FPGA core library
--
-- Copyright 2014-2022 by Andre Souto (suoto)
--
-- Licensed under the CERN-OHL-W v2 (https://cern.ch/cern-ohl).
-- Source location: https://github.com/suoto/fpga_cores

-- Replay testbench for the axi_stream_fifo BMC counterexample.
--
-- It drives the DUT's free inputs (rst, s_tvalid, s_tdata, m_tready) with the
-- exact per-cycle stimulus sby found (formal/axi_stream_fifo_bmc), then dumps a
-- GHDL-native .ghw so Surfer shows the axi_bus_t records (bypass, ram_wr,
-- ram_rd_resp, ...) with named .tdata/.tvalid/.tready fields — impossible from
-- the flattened smt2 VCD.
--
-- Regenerate the stimulus arrays below from a fresh trace with:
--   python3 formal/gen_replay_stim.py

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.env.all;

library fpga_cores;
use fpga_cores.common_pkg.all;

entity axi_stream_fifo_replay_tb is
  generic (
    FIFO_DEPTH : positive := 8;   -- must match the value BMC ran with
    DATA_WIDTH : positive := 8);
end axi_stream_fifo_replay_tb;

architecture tb of axi_stream_fifo_replay_tb is

  type slv_data_array is array (natural range <>) of std_logic_vector(DATA_WIDTH - 1 downto 0);

  -- Counterexample stimulus: cycles 0..10 recorded, 11..16 added to drain.
  constant RST_SEQ    : std_logic_vector := "10000000000000000";
  constant SVALID_SEQ : std_logic_vector := "01111101100000000";
  constant MREADY_SEQ : std_logic_vector := "00001001111111111";
  constant SDATA_SEQ  : slv_data_array   := (
    x"00", x"00", x"01", x"02", x"03", x"04", x"04", x"05", x"06",
    x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00");

  signal clk      : std_logic := '0';
  signal rst      : std_logic := '1';
  signal s_tvalid : std_logic := '0';
  signal s_tready : std_logic;
  signal s_tdata  : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
  signal m_tvalid : std_logic;
  signal m_tready : std_logic := '0';
  signal m_tdata  : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal entries  : std_logic_vector(numbits(FIFO_DEPTH) downto 0);
  signal empty    : std_logic;
  signal full     : std_logic;

begin

  clk <= not clk after 5 ns;

  dut : entity fpga_cores.axi_stream_fifo
    generic map (
      FIFO_DEPTH => FIFO_DEPTH,
      DATA_WIDTH => DATA_WIDTH,
      RAM_TYPE   => "auto")
    port map (
      clk      => clk,
      rst      => rst,
      entries  => entries,
      empty    => empty,
      full     => full,
      s_tvalid => s_tvalid,
      s_tready => s_tready,
      s_tdata  => s_tdata,
      m_tvalid => m_tvalid,
      m_tready => m_tready,
      m_tdata  => m_tdata);

  stim : process
  begin
    for k in RST_SEQ'range loop
      rst      <= RST_SEQ(k);
      s_tvalid <= SVALID_SEQ(k);
      m_tready <= MREADY_SEQ(k);
      s_tdata  <= SDATA_SEQ(k);
      wait until rising_edge(clk);
    end loop;
    wait for 20 ns;
    report "replay done" severity note;
    finish;
  end process;

end tb;
