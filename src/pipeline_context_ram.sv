//
// FPGA core library
//
// Copyright 2020-2022 by Andre Souto (suoto)
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

module pipeline_context_ram #(
  parameter int unsigned DEPTH      = 16,
  parameter int unsigned DATA_WIDTH = 16,
  parameter string       RAM_TYPE   = "auto"
) (
    input wire logic                          clk,
    // Checkout request interface
    input wire logic                          en_in,
    input wire logic [ $clog2(DEPTH)-1:0 ]    addr_in,
    // Data checkout output
    output     logic                          en_out,
    output     logic [ $clog2(DEPTH)-1:0 ]    addr_out,
    output     logic [ DATA_WIDTH-1:0 ]       context_out,
    // Updated data input
    input wire logic [ DATA_WIDTH-1:0 ]       context_in
);

// end pipeline_context_ram;
//
// architecture pipeline_context_ram of pipeline_context_ram is
//
//   constant ADDR_WIDTH : integer := numbits(DEPTH);
//   //---------
//   // Types --
//   //---------
//   type addr_array_t is array (natural range <>) of std_logic_vector(ADDR_WIDTH - 1 downto 0);
//
//   //-----------
//   // Signals --
//   //-----------
//   signal ram_rddata     : std_logic_vector(DATA_WIDTH - 1 downto 0);
//   signal context_in_reg : std_logic_vector(DATA_WIDTH - 1 downto 0);
//
//   signal addr_out_i     : std_logic_vector(ADDR_WIDTH - 1 downto 0);
//   signal addr_sr        : addr_array_t(3 downto 0);
//   signal en_sr          : std_logic_vector(3 downto 0);
//
//   signal unconnected_rddata_a   : std_logic_vector(DATA_WIDTH - 1 downto 0); // Fifo read data
//
// begin
//
//   //-----------------
//   // Port mappings --
//   //-----------------
//   ram_u : entity work.ram_inference
//     generic map (
//       DEPTH        => DEPTH,
//       DATA_WIDTH   => DATA_WIDTH,
//       RAM_STYLE    => RAM_TYPE,
//       // TODO: Adjust the pipeline to handle OUTPUT_DELAY = 2 to get better timing on
//       // Xilinx devices (see message Synth 8-7053)
//       OUTPUT_DELAY => 1)
//     port map (
//       // Port A
//       clk_a     => clk,
//       en_a      => '1',
//       wren_a    => en_sr(1),
//       addr_a    => addr_sr(1),
//       wrdata_a  => context_in,
//       rddata_a  => unconnected_rddata_a,
//
//       // Port B
//       clk_b     => clk,
//       en_b      => '1',
//       addr_b    => addr_in,
//       rddata_b  => ram_rddata);
//
//   //----------------------------
//   // Asynchronous assignments --
//   //----------------------------
//   // Return data from the SRs if we have it in our internal pipelines
//   context_out <= context_in when addr_out_i = addr_sr(1) and en_sr(1) = '1' else
//                  context_in_reg when addr_out_i = addr_sr(2) and en_sr(2) = '1' else
//                  ram_rddata;
//
//   en_out     <= en_sr(0);
//   addr_out_i <= addr_sr(0);
//
//   addr_out   <= addr_out_i;
//
//   //-------------
//   // Processes --
//   //-------------
//   process(clk)
//   begin
//     if rising_edge(clk) then
//       context_in_reg <= context_in;
//       addr_sr        <= addr_sr(addr_sr'length - 2 downto 0) & addr_in;
//       en_sr          <= en_sr(en_sr'length - 2 downto 0) & en_in;
//     end if;
//   end process;
//
// end pipeline_context_ram;

endmodule
