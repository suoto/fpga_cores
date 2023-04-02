--
-- FPGA core library
--
-- Copyright 2022 by Andre Souto (suoto)
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

---------------------------------
-- Block name and description --
--------------------------------

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
entity axi_stream_ram is
  generic (
    DEPTH         : natural := 16;
    DATA_WIDTH    : natural := 16;
    TAG_WIDTH     : natural := 0;
    INITIAL_VALUE : std_logic_array_t(0 to DEPTH - 1)(DATA_WIDTH - 1 downto 0) := (others => (others => '0'));
    OUTPUT_DELAY  : natural := 0;
    RAM_TYPE      : ram_type_t := auto);
  port (
    clk           : in  std_logic;
    rst           : in  std_logic;
    -- Write side
    wr_tready     : out std_logic;
    wr_tvalid     : in  std_logic;
    wr_addr       : in  std_logic_vector(numbits(DEPTH) - 1 downto 0);
    wr_data_in    : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
    wr_data_out   : out std_logic_vector(DATA_WIDTH - 1 downto 0);

    -- Read request side
    rd_in_tready  : out std_logic;
    rd_in_tvalid  : in  std_logic;
    rd_in_addr    : in  std_logic_vector(numbits(DEPTH) - 1 downto 0);
    rd_in_tag     : in  std_logic_vector(TAG_WIDTH - 1 downto 0) := (others => 'U');

    -- Read response side
    rd_out_tready : in  std_logic;
    rd_out_tvalid : out std_logic;
    rd_out_addr   : out std_logic_vector(numbits(DEPTH) - 1 downto 0);
    rd_out_data   : out std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => 'U');
    rd_out_tag    : out std_logic_vector(TAG_WIDTH - 1 downto 0) := (others => 'U'));
end axi_stream_ram;

architecture axi_stream_ram of axi_stream_ram is

  ---------------
  -- Constants --
  ---------------
  constant ADDR_WIDTH   : integer := numbits(DEPTH);
  constant RAM_LATENCY  : integer := 3;

  -------------
  -- Signals --
  -------------
  signal credit_return_en   : std_logic;
  signal credits_available  : std_logic_vector(numbits(RAM_LATENCY + 1) - 1 downto 0);

  signal ram_rd_tready      : std_logic;
  signal ram_rd_tvalid      : std_logic;
  signal ram_rd_addr        : std_logic_vector(ADDR_WIDTH - 1 downto 0);
  signal ram_rd_tag         : std_logic_vector(TAG_WIDTH - 1 downto 0) := (others => 'U');

  signal ram_rd_sync_tready : std_logic;
  signal ram_rd_sync_tvalid : std_logic;
  signal ram_rd_sync_addr   : std_logic_vector(ADDR_WIDTH - 1 downto 0);
  signal ram_rd_sync_tag    : std_logic_vector(TAG_WIDTH - 1 downto 0) := (others => 'U');
  signal ram_rd_sync_data   : std_logic_vector(DATA_WIDTH - 1 downto 0);

  signal output_fifo_wr_en  : std_logic;
  signal output_fifo_full   : std_logic;
  signal output_fifo_empty  : std_logic;

begin

  wr_tready <= '1';

  -------------------
  -- Port mappings --
  -------------------
  -- RAM has read latency, so allocate credits for that
  input_credit_block : block
    signal tdata_agg_in  : std_logic_vector(ADDR_WIDTH + TAG_WIDTH - 1 downto 0);
    signal tdata_agg_out : std_logic_vector(ADDR_WIDTH + TAG_WIDTH - 1 downto 0);
  begin
    tdata_agg_in              <= rd_in_tag & rd_in_addr;
    (ram_rd_tag, ram_rd_addr) <= tdata_agg_out;

    input_credit_u : entity work.axi_stream_credit
      generic map (
        CREDITS     => RAM_LATENCY,
        TDATA_WIDTH => ADDR_WIDTH + TAG_WIDTH)
      port map (
        clk               => clk,
        rst               => rst,

        credit_return_en  => credit_return_en,
        credit_return     => std_logic_vector(to_unsigned(1, credits_available'length)),
        credits_available => credits_available,

        -- AXI slave input
        s_tvalid          => rd_in_tvalid,
        s_tready          => rd_in_tready,
        s_tdata           => tdata_agg_in,

        -- AXI master output
        m_tvalid          => ram_rd_tvalid,
        m_tready          => ram_rd_tready,
        m_tdata           => tdata_agg_out);
  end block;

  ram_u : entity work.ram_inference
    generic map (
      DEPTH         => DEPTH,
      DATA_WIDTH    => DATA_WIDTH,
      RAM_TYPE      => RAM_TYPE,
      INITIAL_VALUE => INITIAL_VALUE,
      OUTPUT_DELAY  => 2) -- Assume BRAM style latency
    port map (
      -- Port A
      clk_a     => clk,
      clken_a   => '1',
      wren_a    => wr_tvalid,
      addr_a    => wr_addr,
      wrdata_a  => wr_data_in,
      rddata_a  => wr_data_out,
      -- Port B
      clk_b     => clk,
      clken_b   => '1',
      addr_b    => ram_rd_addr,
      rddata_b  => ram_rd_sync_data);

  -- Delay RAM read input to synchronize with the cycle the output data actually comes out
  -- of the RAM
  ram_rd_delay_block : block
    signal tdata_agg_in  : std_logic_vector(ADDR_WIDTH + TAG_WIDTH - 1 downto 0);
    signal tdata_agg_out : std_logic_vector(ADDR_WIDTH + TAG_WIDTH - 1 downto 0);
  begin

    tdata_agg_in     <= ram_rd_tag & ram_rd_addr;
    ram_rd_sync_addr <= tdata_agg_out(ADDR_WIDTH - 1 downto 0);
    ram_rd_sync_tag  <= tdata_agg_out(ADDR_WIDTH + TAG_WIDTH - 1 downto ADDR_WIDTH);

    ram_rd_delay_u : entity work.axi_stream_delay
      generic map (
        DELAY_CYCLES => 2,
        TDATA_WIDTH  => ADDR_WIDTH + TAG_WIDTH)
      port map (
        -- Usual ports
        clk     => clk,
        rst     => rst,

        -- AXI slave input
        s_tvalid => ram_rd_tvalid,
        s_tready => ram_rd_tready,
        s_tdata  => tdata_agg_in,

        -- AXI master output
        m_tvalid => ram_rd_sync_tvalid,
        m_tready => ram_rd_sync_tready,
        m_tdata  => tdata_agg_out);
  end block;

  output_buffer_block : block
    signal tdata_agg_in       : std_logic_vector(ADDR_WIDTH + TAG_WIDTH + DATA_WIDTH - 1 downto 0);
    signal output_fifo_tdata  : std_logic_vector(ADDR_WIDTH + TAG_WIDTH + DATA_WIDTH - 1 downto 0);
    signal output_fifo_tvalid : std_logic;
    signal output_fifo_tready : std_logic;
    signal tdata_agg_out      : std_logic_vector(ADDR_WIDTH + TAG_WIDTH + DATA_WIDTH - 1 downto 0);
  begin
    credit_return_en <= output_fifo_tvalid and output_fifo_tready;
    tdata_agg_in     <= ram_rd_sync_tag & ram_rd_sync_data & ram_rd_sync_addr;

    ram_rd_sync_tready <= not output_fifo_full;
    output_fifo_wr_en  <= ram_rd_sync_tvalid and ram_rd_sync_tready;

    -- Use a very small FIFO to handle backpressure until the pipe stops. The
    -- credits mechanism should prevent this FIFO from overflowing
    output_fifo_u : entity work.sync_fifo
      generic map (
        RAM_TYPE           => lut,
        DEPTH              => RAM_LATENCY + 1,
        DATA_WIDTH         => ADDR_WIDTH + DATA_WIDTH + TAG_WIDTH,
        EXTRA_OUTPUT_DELAY => 0)
      port map (
        clk     => clk,
        clken   => '1',
        rst     => rst,

        -- Status
        full    => output_fifo_full,
        upper   => open,
        lower   => open,
        empty   => output_fifo_empty,

        -- Write port
        wr_en   => output_fifo_wr_en,
        wr_data => tdata_agg_in,

        -- Read port
        rd_en   => output_fifo_tready,
        rd_data => output_fifo_tdata,
        rd_dv   => output_fifo_tvalid);

    output_delay_u : entity work.axi_stream_delay
      generic map (
        DELAY_CYCLES => OUTPUT_DELAY,
        TDATA_WIDTH  => ADDR_WIDTH + DATA_WIDTH + TAG_WIDTH)
      port map (
        -- Usual ports
        clk     => clk,
        rst     => rst,

        -- AXI slave input
        s_tvalid => output_fifo_tvalid,
        s_tready => output_fifo_tready,
        s_tdata  => output_fifo_tdata,

        -- AXI master output
        m_tvalid => rd_out_tvalid,
        m_tready => rd_out_tready,
        m_tdata  => tdata_agg_out);

    rd_out_addr <= tdata_agg_out(ADDR_WIDTH - 1 downto 0);
    rd_out_data <= tdata_agg_out(ADDR_WIDTH + DATA_WIDTH - 1 downto ADDR_WIDTH);
    rd_out_tag  <= tdata_agg_out(ADDR_WIDTH + DATA_WIDTH + TAG_WIDTH - 1 downto ADDR_WIDTH + DATA_WIDTH);
  end block;

end axi_stream_ram;
