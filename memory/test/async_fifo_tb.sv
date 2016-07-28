//
// hdl_lib -- A(nother) HDL library
//
// Copyright 2016 by Andre Souto (suoto)
//
// This file is part of hdl_lib.
//
// hdl_lib is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// hdl_lib is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with hdl_lib.  If not, see <http://www.gnu.org/licenses/>.
`include "vunit_defines.svh"

// #####################################################################################
// ## Asynchronous FIFO test bench code ################################################
// #####################################################################################
module async_fifo_tb;
  // Test bench config
  parameter WR_CLK_PERIOD    = 4ns;
  parameter RD_CLK_PERIOD    = 16ns;
  parameter WR_EN_RANDOM     = 10;
  parameter RD_EN_RANDOM     = 10;
  // DUT generic configuration
  parameter FIFO_LEN         = 512;         // FIFO length in number of positions
  parameter UPPER_TRESHOLD   = 510;         // FIFO level to assert wr_upper
  parameter LOWER_TRESHOLD   = 10;          // FIFO level to assert rd_lower
  parameter DATA_WIDTH       = 8;           // Data width
  parameter OVERFLOW_ACTION  = "SATURATE";
  parameter UNDERFLOW_ACTION = "SATURATE";

  // ###################################################################################
  // ## Connections to the DUT #########################################################
  // ###################################################################################
  logic wr_clk   = 1'b0;            // Write clock
  logic wr_clken = 1'b1;            // Write clock enable
  logic wr_arst;                    // Write side asynchronous reset
  logic [DATA_WIDTH - 1:0] wr_data; // FIFO write data
  logic wr_en;                      // FIFO write enable
  logic wr_full;                    // FIFO write full status
  logic wr_upper;                   // FIFO write upper status

  logic rd_clk   = 1'b0;            // Read clock
  logic rd_clken = 1'b1;            // Read clock enable
  logic rd_arst;                    // Read side asynchronous reset
  logic [DATA_WIDTH - 1:0] rd_data; // FIFO read data
  logic rd_en;                      // FIFO read enable
  logic rd_dv;                      // FIFO read data valid
  logic rd_lower;                   // FIFO read full status
  logic rd_empty;                   // FIFO read upper status

  // ###################################################################################
  // ## Test bench stuff ###############################################################
  // ###################################################################################
   int tb_fifo[$];


  // Enable test bench watchdog
  `WATCHDOG(1ms);

  // Clock generation
  always begin
    #(WR_CLK_PERIOD/2);
    wr_clk <= !wr_clk;
  end
  always begin
    #(RD_CLK_PERIOD/2);
    rd_clk <= !rd_clk;
  end

  task automatic write_fifo();
    int word = $urandom_range(255);
    @(posedge wr_clk iff wr_clk);
    wr_en   <= 1'b1;
    wr_data <= word;
    tb_fifo.push_back(word);
    @(posedge wr_clk);
    $display("[%t] Wrote 0x%x", $time, wr_data);
    wr_en   <= 1'b0;
    wr_data <= 'bX;
  endtask

  task automatic read_fifo();
    rd_en = 1'b1;
    @(posedge rd_clk iff rd_dv);
    rd_en = 1'b0;
    $display("[%t] Read data: 0x%x", $time, rd_data);
    `CHECK_EQUAL(rd_data, tb_fifo.pop_front());
  endtask

  // -----------------------------------------------------------------------------------
  // -- Connect the DUT ----------------------------------------------------------------
  // -----------------------------------------------------------------------------------
  \memory.async_fifo #(
    .FIFO_LEN(FIFO_LEN),
    .UPPER_TRESHOLD(UPPER_TRESHOLD),
    .LOWER_TRESHOLD(LOWER_TRESHOLD),
    .DATA_WIDTH(DATA_WIDTH),
    .OVERFLOW_ACTION(OVERFLOW_ACTION),
    .UNDERFLOW_ACTION(UNDERFLOW_ACTION))
  dut (.*);

  // ###################################################################################
  // ## Main test suite control ########################################################
  // ###################################################################################
  `TEST_SUITE begin

    `TEST_SUITE_SETUP begin
      $display("[%t] Running test suite setup code", $time);
      // Generate the resets
      wr_arst = 1;
      rd_arst = 1;
      fork : reset_generation
        #(10*WR_CLK_PERIOD) wr_arst = 0;
        #(20*RD_CLK_PERIOD) rd_arst = 0;
      join;
    end

    `TEST_CASE_SETUP begin
      $display("Running test case setup code");
    end

    `TEST_CASE("Write and read from FIFO at max rate") begin
      fork
        // Write some data
        begin
          @(posedge wr_clk);
          write_fifo();
          write_fifo();
          write_fifo();
          #(1us);
        end
        // Read some data
        begin
          @(posedge rd_clk);
          for (int i=0; i<7; i++) begin
            $display("[%t] Reading value %3d", $time, i);
            read_fifo();
          end
          #(1us);
        end
      join_any;
    end

    `TEST_CASE_CLEANUP begin
      // This section will run after the end of a test case. In
      // many cases this section will not be needed.
      $display("Cleaning up after a test case");
    end

    `TEST_SUITE_CLEANUP begin
      // This section will run last before the TEST_SUITE block
      // exits. In many cases this section will not be needed.
      $display("Cleaning up after running the complete test suite");
    end
  end;

endmodule


