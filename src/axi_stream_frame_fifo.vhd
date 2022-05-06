--
-- FPGA core library
--
-- Copyright 2020-2021 by Andre Souto (suoto)
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

---------------
-- Libraries --
---------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common_pkg.all;

------------------------
-- Entity declaration --
------------------------
entity axi_stream_frame_fifo is
  generic (
    FIFO_DEPTH : natural    := 1;
    DATA_WIDTH : natural    := 1;
    RAM_TYPE   : ram_type_t := auto);
  port (
    -- Usual ports
    clk     : in  std_logic;
    rst     : in  std_logic;

    -- status
    entries  : out std_logic_vector(numbits(FIFO_DEPTH) downto 0);
    empty    : out std_logic;
    full     : out std_logic;

    -- Write side
    s_tvalid : in  std_logic;
    s_tready : out std_logic;
    s_tdata  : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
    s_tlast  : in  std_logic;

    -- Read side
    m_tvalid : out std_logic;
    m_tready : in  std_logic;
    m_tdata  : out std_logic_vector(DATA_WIDTH - 1 downto 0);
    m_tlast  : out std_logic);
end axi_stream_frame_fifo;

architecture axi_stream_frame_fifo of axi_stream_frame_fifo is

  -------------
  -- Signals --
  -------------
  signal s_tready_i    : std_logic;

  signal fifo_empty    : std_logic;
  signal fifo_m_tvalid : std_logic;
  signal fifo_m_tready : std_logic;

  signal m_tvalid_i    : std_logic;
  signal m_tlast_i     : std_logic;

  signal frame_count   : unsigned(numbits(FIFO_DEPTH) downto 0);

  signal s_axi_dv      : std_logic;
  signal s_axi_eof     : std_logic;
  signal m_axi_dv      : std_logic;
  signal m_axi_eof     : std_logic;

begin

  -------------------
  -- Port mappings --
  -------------------
  fifo_u : entity work.axi_stream_fifo
    generic map (
      FIFO_DEPTH => FIFO_DEPTH,
      DATA_WIDTH => DATA_WIDTH,
      RAM_TYPE   => RAM_TYPE)
    port map (
      -- Usual ports
      clk     => clk,
      rst     => rst,

      -- status
      entries  => entries,
      empty    => fifo_empty,
      full     => full,

      -- Write side
      s_tvalid => s_tvalid,
      s_tready => s_tready_i,
      s_tdata  => s_tdata,
      s_tlast  => s_tlast,

      -- Read side
      m_tvalid => fifo_m_tvalid,
      m_tready => fifo_m_tready,
      m_tdata  => m_tdata,
      m_tlast  => m_tlast_i
    );

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  m_tvalid <= m_tvalid_i;
  m_tlast  <= m_tlast_i;

  s_tready <= s_tready_i;

  empty    <= '1' when frame_count = 0 else fifo_empty;

  -- Break the output flow if there's no completed frame inside the FIFO
  m_tvalid_i    <= fifo_m_tvalid when frame_count > 0 else '0';
  fifo_m_tready <= m_tready      when frame_count > 0 else '0';

  s_axi_dv      <= s_tvalid and s_tready_i;
  m_axi_dv      <= m_tvalid and m_tready;

  s_axi_eof     <= s_axi_dv and s_tlast;
  m_axi_eof     <= m_axi_dv and m_tlast_i;

  ---------------
  -- Processes --
  ---------------
  process(clk, rst)
  begin
    if rst = '1' then
      frame_count <= (others => '0');
    elsif rising_edge(clk) then
      if s_axi_eof = '1' and m_axi_eof = '0' then
        frame_count <= frame_count + 1;
      elsif s_axi_eof = '0' and m_axi_eof = '1' then
        frame_count <= frame_count - 1;
      end if;
    end if;
  end process;

end axi_stream_frame_fifo;
