--
-- FPGA core library
--
-- Copyright 2016-2021 by Andre Souto (suoto)
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

-- Replicate a single stream to multiple targets

library ieee;
use ieee.std_logic_1164.all;

use work.common_pkg.all;

------------------------
-- Entity declaration --
------------------------
entity axi_stream_replicate is
  generic (
    INTERFACES  : integer := 2;
    TDATA_WIDTH : integer := 8
  );
  port (
    -- Usual ports
    clk       : in  std_logic;
    rst       : in  std_logic;

    -- AXI stream input
    s_tvalid  : in  std_logic;
    s_tready  : out std_logic;
    s_tdata   : in  std_logic_vector(TDATA_WIDTH - 1 downto 0);
    -- AXI stream outputs
    m_tvalid  : out std_logic_vector(INTERFACES - 1 downto 0);
    m_tready  : in  std_logic_vector(INTERFACES - 1 downto 0);
    m_tdata   : out std_logic_array_t(INTERFACES - 1 downto 0)(TDATA_WIDTH - 1 downto 0));
end axi_stream_replicate;

architecture axi_stream_replicate of axi_stream_replicate is

  -------------
  -- Signals --
  -------------
  signal s_tdata_i  : std_logic_vector(TDATA_WIDTH - 1 downto 0);
  signal s_tready_i : std_logic;
  signal m_tvalid_i : std_logic_vector(INTERFACES - 1 downto 0);

  signal s_axi_dv   : std_logic;
  signal m_axi_dv   : std_logic_vector(INTERFACES - 1 downto 0);

  signal dbg_count  : integer_vector_t(0 to INTERFACES - 1);

begin

  -------------------
  -- Port mappings --
  -------------------

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  s_axi_dv   <= s_tready_i and s_tvalid;
  m_axi_dv   <= m_tvalid_i and m_tready;

  g_tdata : for i in 0 to INTERFACES - 1 generate
    m_tdata(i) <= s_tdata_i when m_tvalid_i(i) else (others => 'U');
  end generate;

  s_tready_i <= and(m_tvalid_i and m_tready) or and(not m_tvalid_i);

  s_tready   <= s_tready_i;
  m_tvalid   <= m_tvalid_i;

  ---------------
  -- Processes --
  ---------------
  process(clk, rst)
  begin
    if rst = '1' then
      m_tvalid_i <= (others => '0');
    elsif rising_edge(clk) then
      -- Deassert tvalid of interfaces that have accepted data
      m_tvalid_i <= m_tvalid_i and not m_tready;

      -- Drive data to all interfaces
      if s_axi_dv then
        m_tvalid_i <= (others => '1');
        s_tdata_i  <= s_tdata;
      end if;
    end if;
  end process;

  -- Simulation only debug
  -- synthesis translate_off
  process(clk, rst)
  begin
    if rst then
      dbg_count <= (others => 0);
    elsif rising_edge(clk) then
      for i in 0 to INTERFACES - 1 loop
        if m_axi_dv(i) then
          dbg_count(i) <= dbg_count(i) + 1;
        end if;
      end loop;
    end if;
  end process;
  -- synthesis translate_on

end axi_stream_replicate;
