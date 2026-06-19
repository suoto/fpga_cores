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
--
-- As per CERN-OHL-W v2 section 4.1, should You produce hardware based on these
-- sources, You must maintain the Source Location visible on the external case
-- of the FPGA Cores or other product you make using this documentation.


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common_pkg.all;

entity axi_stream_fifo is
  generic (
    FIFO_DEPTH : positive := 10;
    DATA_WIDTH : positive := 8;
    RAM_TYPE   : string   := "auto");
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

    -- Read side
    m_tvalid : out std_logic;
    m_tready : in  std_logic;
    m_tdata  : out std_logic_vector(DATA_WIDTH - 1 downto 0));
end axi_stream_fifo;

architecture fast of axi_stream_fifo is

  type axi_bus_t is record
    tdata  : std_logic_vector(DATA_WIDTH - 1 downto 0);
    tvalid : std_logic;
    tready : std_logic;
  end record;

  constant MAIN_RAM_LATENCY : integer := 5;

  -- signal s_axi_dv    : std_logic;
  -- signal m_axi_dv    : std_logic;

  -- signal ram_wr_ptr  : unsigned(numbits(FIFO_DEPTH) downto 0);
  -- signal ram_rd_ptr  : unsigned(numbits(FIFO_DEPTH) downto 0);
  -- signal ptr_diff    : unsigned(numbits(FIFO_DEPTH) downto 0);

  -- -- Internals
  -- signal ram_wr_addr : std_logic_vector(numbits(FIFO_DEPTH) - 1 downto 0);
  -- signal ram_rd_addr : std_logic_vector(numbits(FIFO_DEPTH) - 1 downto 0);

  signal skid_buffer_bypass   : std_logic;
  signal fifo                 : axi_bus_t;
  signal bypass               : axi_bus_t;
  signal skid_buffer_in       : axi_bus_t;

begin

  input_data_fork_u : entity work.axi_stream_demux
    generic map (
      INTERFACES => 2,
      DATA_WIDTH => DATA_WIDTH)
    port map (
      selection_mask => (0 => skid_buffer_bypass, 1 => not skid_buffer_bypass),

      s_tvalid       => s_tvalid,
      s_tready       => s_tready,
      s_tdata        => s_tdata,

      m_tvalid(0)    => bypass.tvalid,
      m_tvalid(1)    => fifo.tvalid,
      m_tready(0)    => bypass.tready,
      m_tready(1)    => fifo.tready,
      m_tdata(0)     => bypass.tdata,
      m_tdata(1)     => fifo.tdata
    );


  -- s_axi_dv    <= s_tready and s_tvalid;
  -- m_axi_dv    <= m_tready and m_tvalid;
  --
  -- -- Read when ram is not full and pointer diff is not 0
  -- m_tvalid    <= or(ptr_diff);
  --
  -- s_tready    <= not full;
  --
  -- -- GHDL fails with bound check error if this is wired directly
  -- ram_wr_addr <= std_logic_vector(ram_wr_ptr(ram_wr_ptr'length - 2 downto 0));
  -- ram_rd_addr <= std_logic_vector(ram_rd_ptr(ram_rd_ptr'length - 2 downto 0));
  --
  -- entries     <= std_logic_vector(ptr_diff);
  -- -- FIFO is empty when the output adapter is empty and ptr diff is 0
  -- empty       <= and(not ptr_diff);
  -- -- Full when ptr_diff equals FIFO depth, i.e., delta is all 0s
  -- full        <= '1' when ptr_diff = FIFO_DEPTH else '0';


  skid_buffer_mux_u : entity work.axi_stream_mux
    generic map (
      INTERFACES => 2,
      DATA_WIDTH => DATA_WIDTH)
    port map (
      selection_mask => (0 => skid_buffer_bypass, 1 => not skid_buffer_bypass),

      s_tvalid(0)    => bypass.tvalid,
      s_tvalid(1)    => fifo.tvalid,
      s_tready(0)    => bypass.tready,
      s_tready(1)    => fifo.tready,
      s_tdata(0)     => bypass.tdata,
      s_tdata(1)     => fifo.tdata,

      m_tvalid       => skid_buffer_in.tvalid,
      m_tready       => skid_buffer_in.tready,
      m_tdata        => skid_buffer_in.tdata
    );

  -- Use a simple FIFO whose memory latency is small to handle the latency of
  -- BRAM / URAM. As long as the receiver has no backpressure, the bigger
  -- memory will never see any data
  skid_buffer_u : entity work.axi_stream_fifo_simple
    generic map (
      FIFO_DEPTH => MAIN_RAM_LATENCY,
      DATA_WIDTH => DATA_WIDTH,
      RAM_TYPE   => "auto") -- only types with 0 output delay are accepted (distributed, registers)
    port map (
      -- Usual ports
      clk     => clk,
      rst     => rst,

      -- status
      entries  => open,
      empty    => open,
      full     => open,

      -- Write side
      s_tvalid => skid_buffer_in.tvalid,
      s_tready => skid_buffer_in.tready,
      s_tdata  => skid_buffer_in.tdata,
      s_tlast  => '0',

      -- Read side
      m_tvalid => m_tvalid,
      m_tready => m_tready,
      m_tdata  => m_tdata,
      m_tlast  => open
    );

  process(clk)
  begin
    if rising_edge(clk) then
      if not skid_buffer_in.tready then
        skid_buffer_bypass <= '0';
      end if;

      if rst then
        skid_buffer_bypass <= '1';
      end if;
    end if;
  end process;

end fast;
