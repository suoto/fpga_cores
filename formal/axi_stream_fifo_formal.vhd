--
-- FPGA core library
--
-- Copyright 2014-2022 by Andre Souto (suoto)
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

-- Formal verification wrapper for axi_stream_fifo.
--
-- The DUT source is left untouched: all properties live here as `-- psl`
-- comments, which GHDL only translates into $assert/$assume/$cover cells when
-- analysed with -fpsl (see formal/axi_stream_fifo.sby). Under normal VUnit sim
-- and yosys synth (neither passes -fpsl) they are inert comments.
--
-- The free formal inputs (s_tvalid, s_tdata, m_tready) are top-level ports so
-- yosys/sby drives them freely; clk/rst are ports too. Everything the DUT
-- drives stays internal so we can reference it in the properties.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library fpga_cores;
use fpga_cores.common_pkg.all;

entity axi_stream_fifo_formal is
  generic (
    -- NOTE: the DUT sizes `entries` as numbits(FIFO_DEPTH)+1 but drives it from
    -- ram_rd_req_ptr_diff which is numbits(FIFO_DEPTH-3)+1 wide, so most depths
    -- fail to elaborate (a latent DUT width bug on this WIP branch). FIFO_DEPTH=8
    -- is a value where the two widths coincide (numbits(8)=numbits(5)=3).
    FIFO_DEPTH : positive := 8;   -- must be > MAIN_RAM_LATENCY (3)
    DATA_WIDTH : positive := 8);
  port (
    clk      : in std_logic;
    rst      : in std_logic;
    -- Free formal inputs (arbitrary legal master / receiver)
    s_tvalid : in std_logic;
    s_tdata  : in std_logic_vector(DATA_WIDTH - 1 downto 0);
    m_tready : in std_logic);
end axi_stream_fifo_formal;

architecture formal of axi_stream_fifo_formal is

  -- DUT outputs / internal observables
  signal s_tready : std_logic;
  signal m_tvalid : std_logic;
  signal m_tdata  : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal empty    : std_logic;
  signal full     : std_logic;
  signal entries  : std_logic_vector(numbits(FIFO_DEPTH) downto 0);

  -- These mirror DUT outputs and are not wrapper ports, so flatten + opt_clean
  -- would otherwise merge them into the `dut` scope. `keep` pins them here so
  -- all observed signals live under axi_stream_fifo_formal in the trace.
  attribute keep : boolean;
  attribute keep of s_tready, m_tvalid, m_tdata, empty, full, entries : signal is true;

  -- Scoreboard: input/output beat counters (ramp method). Because the master is
  -- constrained (below) to always drive s_tdata = wr_expected, proving the n-th
  -- output equals rd_expected proves in-order, corruption-free data transfer.
  signal wr_expected : unsigned(DATA_WIDTH - 1 downto 0);
  signal rd_expected : unsigned(DATA_WIDTH - 1 downto 0);

begin

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

  -- Count accepted input beats
  wr_cnt_p : process(clk)
  begin
    if rising_edge(clk) then
      if s_tvalid = '1' and s_tready = '1' then
        wr_expected <= wr_expected + 1;
      end if;
      if rst = '1' then
        wr_expected <= (others => '0');
      end if;
    end if;
  end process;

  -- Count delivered output beats
  rd_cnt_p : process(clk)
  begin
    if rising_edge(clk) then
      if m_tvalid = '1' and m_tready = '1' then
        rd_expected <= rd_expected + 1;
      end if;
      if rst = '1' then
        rd_expected <= (others => '0');
      end if;
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  -- Properties (PSL) -- only active with GHDL -fpsl
  -- ---------------------------------------------------------------------------
  -- psl default clock is rising_edge(clk);

  -- Exactly one reset pulse at t=0, then run free
  -- psl reset_seq : restrict {rst = '1'; (rst = '0')[*]};

  -- --- Master model (assumptions on the free inputs) -------------------------
  -- Input holds valid+data stable while stalled
  -- psl s_valid_stable : assume always ({s_tvalid = '1' and s_tready = '0' and rst = '0'} |=> {s_tvalid = '1'});
  -- psl s_data_stable  : assume always ({s_tvalid = '1' and s_tready = '0' and rst = '0'} |=> {s_tdata = prev(s_tdata)});
  -- Master always presents the ramp value expected by the scoreboard
  -- psl s_data_ramp    : assume always (s_tvalid = '1' -> s_tdata = std_logic_vector(wr_expected));

  -- --- AXI-stream interface compliance (DUT must obey) -----------------------
  -- Output holds valid+data stable while stalled (no dropped/mutated beat)
  -- psl m_valid_stable : assert always ({m_tvalid = '1' and m_tready = '0' and rst = '0'} |=> {m_tvalid = '1'});
  -- psl m_data_stable  : assert always ({m_tvalid = '1' and m_tready = '0' and rst = '0'} |=> {m_tdata = prev(m_tdata)});

  -- --- Status sanity ---------------------------------------------------------
  -- psl not_empty_and_full : assert always (rst = '0' -> not (empty = '1' and full = '1'));
  -- NOTE: the DUT `empty` port only reflects the deep-RAM stage
  -- (empty <= and(not ram_rd_req_ptr_diff), axi_stream_fifo.vhd:201); it does
  -- NOT account for the skid buffer, so `empty='1'` while m_tvalid='1' is legal.
  -- Hence there is no `empty -> not m_tvalid` assertion here.

  -- --- Data integrity (in-order, no corruption) ------------------------------
  -- psl data_integrity : assert always ((m_tvalid = '1' and m_tready = '1' and rst = '0') -> m_tdata = std_logic_vector(rd_expected));

  -- --- Reachability / anti-vacuity (cover task) ------------------------------
  -- psl c_fill  : cover {full = '1'};
  -- psl c_xfer  : cover {m_tvalid = '1' and m_tready = '1'};
  -- psl c_drain : cover {empty = '1'; (empty = '0')[+]; empty = '1'};

  -- Alternative for arbitrary-data integrity (instead of the ramp above):
  --   declare a held-constant index (assume always idx = prev(idx)), latch
  --   s_tdata into tracked_data when wr_cnt = idx, then
  --   assert (rd_cnt = idx and m_tvalid and m_tready) -> m_tdata = tracked_data.

end formal;
