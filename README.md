# FPGA Cores

![Unit tests](https://github.com/suoto/fpga_cores/workflows/Unit%20tests/badge.svg)

FPGA Cores is a repository of common RTL code mainly targeting FPGAs.

Code is divided in synthesizable, simulation helpers and testbenches.

## Synthesizable code

* FIFOs
  * async_fifo.vhd: dual clock FIFO
  * axi_stream_fifo.vhd: single clock AXI stream FIFO
  * sync_fifo.vhd: single clock FIFO
* AXI Stream infrastructure
  * AXI Stream delay: insert FF delays on an AXI stream data path
  * AXI Stream master adapter: allows arbitrary number of cycles between a full
    signal (aka tready) and the write enable (aka tvalid). The idea is to isolate
    AXI's back pressure from the processing pipeline, making it easier to stop.
  * AXI stream width converter: width converter that supports non multiple ratios
    and non power of 2 data widths
  * AXI stream skid buffer (VHDL version of ZipCPU's original)
* Basic stuff (no explanation needed)
  * Edge detector
  * Pulse synchronizer
  * Shift register delay
  * Synchronizer
* Memories
  * RAM inference (single and dual port)
  * ROM inference
  * Pipeline context RAM: wraps a RAM inference with a small cache that
    eliminates data hazards, allowing reads before data makes in and out of the
    actual memory element
* Misc
  * Exponential Golomb encoder

## Simulation helpers

* AXI file reader: reads a binary file into an AXI stream interface.
  Configuration interface allows reading different files and controlling the
  probability of tvalid being asserted.
* AXI file compare: uses AXI file reader to generate the expected data and
  compares with data input on the AXI stream slave interface
* AXI stream bus functional model: makes it easy to write data to an AXI stream
  master via procedures
* Linked list: implements a generic type double linked list
