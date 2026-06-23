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

  constant MAIN_RAM_LATENCY   : integer := 3;
  constant MAIN_RAM_DEPTH     : integer := FIFO_DEPTH - MAIN_RAM_LATENCY;

  signal skid_buffer_in           : axi_bus_t;
  signal skid_buffer_full         : std_logic;
  signal skid_buffer_empty        : std_logic;
  signal write_to_skid_buffer_reg : std_logic;
  signal write_to_skid_buffer     : std_logic;
  signal write_to_ram             : std_logic;

  signal ram_wr_dv    : std_logic;
  signal ram_rd_req_dv    : std_logic;
  signal ram_rd_resp_dv    : std_logic;

  signal ram_wr_ptr  : unsigned(numbits(MAIN_RAM_DEPTH) downto 0);
  signal ram_rd_ptr  : unsigned(numbits(MAIN_RAM_DEPTH) downto 0);
  signal ram_rd_req_ptr_diff    : unsigned(numbits(MAIN_RAM_DEPTH) downto 0);
  signal ram_rd_resp_ptr_diff    : unsigned(numbits(MAIN_RAM_DEPTH) downto 0);

  signal ram_wr_full    : std_logic;

  -- Internals
  signal ram_wr_addr     : std_logic_vector(numbits(MAIN_RAM_DEPTH) - 1 downto 0);
  signal ram_rd_req_addr : std_logic_vector(numbits(MAIN_RAM_DEPTH) - 1 downto 0);

  signal ram_wr      : axi_bus_t;
  signal ram_rd_req  : axi_bus_t;  -- tdata is not used
  signal ram_rd_resp : axi_bus_t;
  signal bypass      : axi_bus_t;

begin

  write_to_skid_buffer <= write_to_skid_buffer_reg and not skid_buffer_full;
  write_to_ram         <= not write_to_skid_buffer and not ram_wr_full;

  input_data_fork_u : entity work.axi_stream_demux
    generic map (
      INTERFACES => 2,
      DATA_WIDTH => DATA_WIDTH)
    port map (
      selection_mask => (0 => write_to_skid_buffer, 1 => not write_to_skid_buffer),

      s_tvalid       => s_tvalid,
      s_tready       => s_tready,
      s_tdata        => s_tdata,

      m_tvalid(0)    => bypass.tvalid,
      m_tvalid(1)    => ram_wr.tvalid,
      m_tready(0)    => bypass.tready,
      m_tready(1)    => ram_wr.tready,
      m_tdata(0)     => bypass.tdata,
      m_tdata(1)     => ram_wr.tdata
    );

  skid_buffer_mux_u : entity work.axi_stream_mux
    generic map (
      INTERFACES => 2,
      DATA_WIDTH => DATA_WIDTH)
    port map (
      selection_mask => (0 => write_to_skid_buffer, 1 => not write_to_skid_buffer),

      s_tvalid(0)    => bypass.tvalid,
      s_tvalid(1)    => ram_rd_resp.tvalid,
      s_tready(0)    => bypass.tready,
      s_tready(1)    => ram_rd_resp.tready,
      s_tdata(0)     => bypass.tdata,
      s_tdata(1)     => ram_rd_resp.tdata,

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
      empty    => skid_buffer_empty,
      full     => skid_buffer_full,

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

  full <= skid_buffer_full and ram_wr_full;


  process(clk)
  begin
    if rising_edge(clk) then
      -- Switch to the internal RAM when the skid buffer has enough data to
      -- accomodate the RAM latency
      if skid_buffer_full then
        write_to_skid_buffer_reg <= '0';
      end if;
      if skid_buffer_empty then
        write_to_skid_buffer_reg <= '1';
      end if;

      if rst then
        write_to_skid_buffer_reg <= '1';
      end if;
    end if;
  end process;

  ram_wr_dv      <= ram_wr.tready and ram_wr.tvalid;
  ram_rd_req_dv  <= ram_rd_req.tready and ram_rd_req.tvalid;
  ram_rd_resp_dv <= ram_rd_resp.tready and ram_rd_resp.tvalid;

  -- -- Read when ram is not full and pointer diff is not 0
  ram_rd_req.tvalid <= or(ram_rd_req_ptr_diff);

  -- s_tready    <= not full;

  -- GHDL fails with bound check error if this is wired directly
  ram_wr_addr     <= std_logic_vector(ram_wr_ptr(ram_wr_ptr'length - 2 downto 0));
  ram_rd_req_addr <= std_logic_vector(ram_rd_ptr(ram_rd_ptr'length - 2 downto 0));

  entries     <= std_logic_vector(ram_rd_req_ptr_diff);
  -- FIFO is empty when the output adapter is empty and ptr diff is 0
  empty       <= and(not ram_rd_req_ptr_diff);
  -- Full when ram_rd_req_ptr_diff equals FIFO depth, i.e., delta is all 0s
  ram_wr_full        <= '1' when ram_rd_resp_ptr_diff = MAIN_RAM_DEPTH else '0';

  -- AXI stream RAM write port is always available
  ram_wr.tready <= not ram_wr_full;

  ram_u : entity work.axi_stream_ram
    generic map (
      DEPTH         => MAIN_RAM_DEPTH,
      DATA_WIDTH    => DATA_WIDTH,
      RAM_TYPE      => RAM_TYPE)
    port map (
      clk           => clk,
      rst           => rst,
      -- Write side
      wr_tready     => open,
      wr_tvalid     => ram_wr.tvalid,
      wr_addr       => ram_wr_addr,
      wr_data_in    => ram_wr.tdata,
      wr_data_out   => open,

      -- Read request side
      rd_in_tready  => ram_rd_req.tready,
      rd_in_tvalid  => ram_rd_req.tvalid,
      rd_in_addr    => ram_rd_req_addr,

      -- Read response side
      rd_out_tready => ram_rd_resp.tready,
      rd_out_tvalid => ram_rd_resp.tvalid,
      rd_out_addr   => open,
      rd_out_data   => ram_rd_resp.tdata);

  process(clk)
  begin
    if rising_edge(clk) then
      -- Handle write pointer increment (MAIN_RAM_DEPTH is not necessarily a power of 2)
      if ram_wr_dv then
        if ram_wr_ptr = MAIN_RAM_DEPTH - 1 then
          ram_wr_ptr <= (others => '0');
        else
          ram_wr_ptr <= ram_wr_ptr + 1;
        end if;
      end if;

      -- Handle read pointer increment (MAIN_RAM_DEPTH is not necessarily a power of 2)
      if ram_rd_req_dv then
        if ram_rd_ptr = MAIN_RAM_DEPTH - 1 then
          ram_rd_ptr <= (others => '0');
        else
          ram_rd_ptr <= ram_rd_ptr + 1;
        end if;
      end if;

      -- Calculate the pointer difference without using the actual pointers; MAIN_RAM_DEPTH is
      -- not necessarily a power of 2
      if ram_wr_dv and not ram_rd_req_dv then
        ram_rd_req_ptr_diff <= ram_rd_req_ptr_diff + 1;
      elsif not ram_wr_dv and ram_rd_req_dv then
        ram_rd_req_ptr_diff <= ram_rd_req_ptr_diff - 1;
      end if;

      if ram_wr_dv and not ram_rd_resp_dv then
        ram_rd_resp_ptr_diff <= ram_rd_resp_ptr_diff + 1;
      elsif not ram_wr_dv and ram_rd_resp_dv then
        ram_rd_resp_ptr_diff <= ram_rd_resp_ptr_diff - 1;
      end if;

      if rst then
        ram_rd_req_ptr_diff  <= (others => '0');
        ram_rd_resp_ptr_diff <= (others => '0');
        ram_wr_ptr           <= (others => '0');
        ram_rd_ptr           <= (others => '0');
      end if;
    end if;
  end process;

end fast;
