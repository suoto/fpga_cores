//
// FPGA core library
//
// Copyright 2020-2021 by Andre Souto (suoto)
//
// This source describes Open Hardware and is licensed under the CERN-OHL-W v2
//
// You may redistribute and modify this documentation and make products using it
// under the terms of the CERN-OHL-W v2 (https:/cern.ch/cern-ohl).This
// documentation is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY,
// INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A
// PARTICULAR PURPOSE. Please see the CERN-OHL-W v2 for applicable conditions.
//
// Source location: https://github.com/suoto/fpga_cores
//
// As per CERN-OHL-W v2 section 4.1, should You produce hardware based on these
// sources, You must maintain the Source Location visible on the external case
// of the FPGA Cores or other product you make using this documentation.

`timescale 1ns / 1ps
`default_nettype none

module axi_stream_frame_fifo #(
  parameter int unsigned FIFO_DEPTH = 1,
  parameter int unsigned DATA_WIDTH = 1,
  parameter string       RAM_TYPE   = "auto"
) (
    // Usual ports
    input wire logic                            clk,
    input wire logic                            rst,

    // Status
    output     logic [ $clog2(FIFO_DEPTH):0 ]   entries,
    output     logic                            empty,
    output     logic                            full,

    // Write side
    input wire logic                            s_tvalid,
    output     logic                            s_tready,
    input wire logic [ DATA_WIDTH-1:0 ]         s_tdata,
    input wire logic                            s_tlast,

    // Read side
    output     logic                            m_tvalid,
    input wire logic                            m_tready,
    output     logic [ DATA_WIDTH-1:0 ]         m_tdata,
    output     logic                            m_tlast
);

// end axi_stream_frame_fifo;
//
// architecture axi_stream_frame_fifo of axi_stream_frame_fifo is
//
//   //-----------
//   // Signals --
//   //-----------
//   signal s_tready_i    : std_logic;
//
//   signal fifo_empty    : std_logic;
//   signal fifo_m_tvalid : std_logic;
//   signal fifo_m_tready : std_logic;
//   signal fifo_m_tdata  : std_logic_vector(DATA_WIDTH - 1 downto 0);
//
//   signal m_tvalid_i    : std_logic;
//   signal m_tlast_i     : std_logic;
//
//   signal frame_count   : unsigned(numbits(FIFO_DEPTH) downto 0);
//
//   signal s_axi_dv      : std_logic;
//   signal s_axi_eof     : std_logic;
//   signal m_axi_dv      : std_logic;
//   signal m_axi_eof     : std_logic;
//
// begin
//
//   //-----------------
//   // Port mappings --
//   //-----------------
//   fifo_u : entity work.axi_stream_fifo
//     generic map (
//       FIFO_DEPTH                => FIFO_DEPTH,
//       DATA_WIDTH                => DATA_WIDTH,
//       RAM_STYLE                 => RAM_TYPE,
//       EXTRA_OUTPUT_DELAY_CYCLES => 2)
//     port map (
//       // Usual ports
//       clk     => clk,
//       rst     => rst,
//
//       // status
//       entries  => entries,
//       empty    => fifo_empty,
//       full     => full,
//
//       // Write side
//       s_tvalid => s_tvalid,
//       s_tready => s_tready_i,
//       s_tdata  => s_tdata,
//       s_tlast  => s_tlast,
//
//       // Read side
//       m_tvalid => fifo_m_tvalid,
//       m_tready => fifo_m_tready,
//       m_tdata  => fifo_m_tdata,
//       m_tlast  => m_tlast_i
//     );
//
//   //----------------------------
//   // Asynchronous assignments --
//   //----------------------------
//   m_tvalid <= m_tvalid_i;
//   m_tdata  <= fifo_m_tdata when m_tvalid_i else (others => 'U');
//   m_tlast  <= m_tlast_i when m_tvalid_i else 'U';
//
//   s_tready <= s_tready_i;
//
//   empty    <= '1' when frame_count = 0 else fifo_empty;
//
//   // Break the output flow if there's no completed frame inside the FIFO
//   m_tvalid_i    <= fifo_m_tvalid when frame_count > 0 else '0';
//   fifo_m_tready <= m_tready      when frame_count > 0 else '0';
//
//   s_axi_dv      <= s_tvalid and s_tready_i;
//   m_axi_dv      <= m_tvalid and m_tready;
//
//   s_axi_eof     <= s_axi_dv and s_tlast;
//   m_axi_eof     <= m_axi_dv and m_tlast_i;
//
//   //-------------
//   // Processes --
//   //-------------
//   process(clk, rst)
//   begin
//     if rst = '1' then
//       frame_count <= (others => '0');
//     elsif rising_edge(clk) then
//       if s_axi_eof = '1' and m_axi_eof = '0' then
//         frame_count <= frame_count + 1;
//       elsif s_axi_eof = '0' and m_axi_eof = '1' then
//         frame_count <= frame_count - 1;
//       end if;
//     end if;
//   end process;
//
// end axi_stream_frame_fifo;

endmodule
