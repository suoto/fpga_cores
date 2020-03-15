# Exponential-Golomb encoder

## Index

[TOC]

---

## Intro

The VHDL module should keep the streaming interface used for other modules.
Since no protocol was specified, I'm assuming [AXI4-Stream][axi_ref_guide] is a
nice fit. Not every AXI4-Stream signals are required, so the figure below should
be accurate.

```
                 .---------.
          clk -->|         |
          rst -->|         |
                 | Golomb  |
axi_in_tdata  -->| Encoder |--> axi_out_tdata
axi_in_tvalid -->|         |--> axi_out_tvalid
axi_in_tready <--|         |<-- axi_out_tready
                 '---------'
```

---

## Architecture

Encoding data using Exp-Golomb is basically calculating how many bits are
required to represent a given sample plus a few more operations to allow the
decoder to "guess" the original sample.

While calculating how many bits are needed to represent a sample is a matter of
doing log2(x) and rounding the result to the next integer if needed, this can be
costly to FPGAs in terms of LUTs, FFs and timing. Instead of this, an
`if-then-else` is used approach to keep things parametrizable and save resources.

The basic idea is that for input values from `0` to `2^N - 1`, there will be only
`N` output values. In other words, we can compare the input value to a constant
and determine the output value statically. Inside the FPGA this translates into a
ROM that has `N` positions of `N` bits each, plus `N` comparators.

A module's functional architecture is shown below.

```
                 .------------------------------.
          clk -->|       Golomb encoder         |
          rst -->|                              |
                 |  .----------.   .---------.  |
axi_in_tdata  ---|->|          |   |  AXI    |--|--> axi_out_tdata
axi_in_tvalid ---|->| Encoding |==>| output  |--|--> axi_out_tvalid
axi_in_tready <--|--|          |   | packing |<-|--- axi_out_tready
                 |  '----------'   '---------'  |
                 '------------------------------'
```

### Encoding

As the name suggests, the encoding functional block encodes data received from
the AXI input interface and it was designed to handle data continuously.

This block outputs the encoded data value and the encoded data width.

### AXI output packing

The AXI output packing functional block packs encoded data of variable widths
into a single register, discarding unused bits and effectively reducing the
amount of data.

There are some input values for which their encoded counterpart is actually
larger than the original value and when this happens, the block uses the `tready`
output to stop the input data stream before losing data.

By packing data into a register with `DATA_WIDTH` width, it's possible to write
it directly to DDR or serialize them if needed.

### Misc

#### Limitations

* No tests were made with varying axi_out_tready input
* There is no option for different output types other that packed data

#### Improvements

* Simulation runtime check (`exp_golomb_pkg.runtime_check` procedure) should
  check all possible values. It currently checks only a few hard coded values.
* Simulation should include the [AXI protocol checker][axi_checker] to catch
  issues on the AXI implementation

---

## Simulating

Simulation was designed to be a self checking testbench. The tests included are:

* `test_bin_width`: Tests the function that calculates the binary width of a
  given value
* `test_stream_data`: Streams values from 0 to 32,767 continuously and writes the
  output data to a file name `output.bin`. This file can be checked using Python
  by calling `python/exp_golomb/check_sim_file.py` and passing the path to
  `output.bin` as a parameter.

    **NOTE:** One must run the simulation via VUnit and only enable the `test_stream`
  test case: `./run.py exp_golomb_tb_lib.exp_golomb_encoder_tb.test_stream_data`

* `test_data_limits`: Writes `65,535` continuously to check if the module uses
  `axi_in_tready` output to stop the data input. This value was chosen because
  it's the worst case data in terms of compression.

To launch unit tests for the Exp-Golomb encoder, run the following on a terminal:

```
cd vhdl
python run.py
```

This will run the 3 test cases on different simulation runs and check for issues.

[axi_ref_guide]: http://www.xilinx.com/support/documentation/ip_documentation/axi_ref_guide/latest/ug1037-vivado-axi-reference-guide.pdf
[axi_checker]: http://www.xilinx.com/support/documentation/ip_documentation/axis_protocol_checker/v1_1/pg145-axis-protocol-checker.pdf
[vunit]: https://github.com/VUnit/vunit
[nose2]: https://nose2.readthedocs.org/en/latest/
[bitstring]: http://pythonhosted.org/bitstring/
