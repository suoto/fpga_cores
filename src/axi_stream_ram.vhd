--
-- FPGA core library
--
-- Copyright 2019 by Andre Souto (suoto)
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
    ADDR_WIDTH   : natural := 16;
    DATA_WIDTH   : natural := 16;
    TAG_WIDTH    : natural := 0;
    RAM_TYPE     : ram_type_t := auto);
  port (
    clk           : in  std_logic;
    rst           : in  std_logic;
    -- Write side
    wr_tready     : out std_logic;
    wr_tvalid     : in  std_logic;
    wr_addr       : in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
    wr_data_in    : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
    wr_data_out   : out std_logic_vector(DATA_WIDTH - 1 downto 0);

    -- Read request side
    rd_in_tready  : out std_logic;
    rd_in_tvalid  : in  std_logic;
    rd_in_addr    : in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
    rd_in_tag     : in  std_logic_vector(TAG_WIDTH - 1 downto 0) := (others => 'U');

    -- Read response side
    rd_out_tready : in  std_logic;
    rd_out_tvalid : out std_logic;
    rd_out_addr   : out std_logic_vector(ADDR_WIDTH - 1 downto 0);
    rd_out_data   : out std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => 'U');
    rd_out_tag    : out std_logic_vector(TAG_WIDTH - 1 downto 0) := (others => 'U'));
end axi_stream_ram;

architecture axi_stream_ram of axi_stream_ram is

  constant RAM_LATENCY  : integer := 3;

  -------------
  -- Signals --
  -------------
  signal credit_return_en  : std_logic;
  signal credit_return     : std_logic_vector(numbits(RAM_LATENCY) - 1 downto 0);
  signal credits_available : std_logic_vector(numbits(RAM_LATENCY) - 1 downto 0);

  signal ram_rd_tready     : std_logic;
  signal ram_rd_tvalid     : std_logic;
  signal ram_rd_addr       : std_logic_vector(ADDR_WIDTH - 1 downto 0);
  signal ram_rd_tag        : std_logic_vector(TAG_WIDTH - 1 downto 0) := (others => 'U');

  signal ram_rd_sync_tready    : std_logic;
  signal ram_rd_sync_tvalid    : std_logic;
  signal ram_rd_sync_addr      : std_logic_vector(ADDR_WIDTH - 1 downto 0);
  signal ram_rd_sync_tag       : std_logic_vector(TAG_WIDTH - 1 downto 0) := (others => 'U');
  signal ram_rd_sync_data      : std_logic_vector(DATA_WIDTH - 1 downto 0);

  signal rd_out_tvalid_i   : std_logic;

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
        credit_return     => std_logic_vector(to_unsigned(1, numbits(RAM_LATENCY))),
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
      ADDR_WIDTH   => ADDR_WIDTH,
      DATA_WIDTH   => DATA_WIDTH,
      RAM_TYPE     => RAM_TYPE,
      OUTPUT_DELAY => 1)
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

    tdata_agg_in                        <= ram_rd_tag & ram_rd_addr;
    (ram_rd_sync_tag, ram_rd_sync_addr) <= tdata_agg_out;

    ram_rd_delay_u : entity work.axi_stream_delay
      generic map (
        DELAY_CYCLES => 1,
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
    signal tdata_agg_in  : std_logic_vector(ADDR_WIDTH + TAG_WIDTH + DATA_WIDTH - 1 downto 0);
    signal tdata_agg_out : std_logic_vector(ADDR_WIDTH + TAG_WIDTH + DATA_WIDTH - 1 downto 0);
  begin

    tdata_agg_in                           <= ram_rd_sync_tag & ram_rd_sync_data & ram_rd_sync_addr;
    (rd_out_tag, rd_out_data, rd_out_addr) <= tdata_agg_out;

    output_fifo_u : entity work.axi_stream_fifo
      generic map (
        FIFO_DEPTH => RAM_LATENCY,
        DATA_WIDTH => ADDR_WIDTH + DATA_WIDTH + TAG_WIDTH,
        RAM_TYPE   => lut)
      port map (
        -- Usual ports
        clk     => clk,
        rst     => rst,

        -- status
        entries  => open,
        empty    => open,
        full     => open,

        -- Write side
        s_tvalid => ram_rd_sync_tvalid,
        s_tready => ram_rd_sync_tready,
        s_tdata  => tdata_agg_in,
        s_tlast  => '0',

        -- Read side
        m_tvalid => rd_out_tvalid_i,
        m_tready => rd_out_tready,
        m_tdata  => tdata_agg_out,
        m_tlast  => open);
  end block;

  rd_out_tvalid <= rd_out_tvalid_i;

  credit_return_en <= rd_out_tvalid_i and rd_out_tready;


end axi_stream_ram;
