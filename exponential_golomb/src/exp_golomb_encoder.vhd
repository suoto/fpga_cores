--
-- hdl_lib -- A(nother) HDL library
--
-- Copyright 2014-2016 by Andre Souto (suoto)
--
-- This file is part of hdl_lib.
-- 
-- hdl_lib is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
-- 
-- In addition to the GNU General Public License terms and conditions,
-- under the section 7 - Additional Terms, include the following:
--    g) All files of this work contain lines identifying the original
--    author and release date. This line SHOULD NOT be removed or
--    changed for any reason unless explicitly allowed by the author in
--    the form of writing. Note that this seeks to prevent this work
--    from being misused. Misuse includes but doesn't limits to code
--    evaluation of candidates from employers. All remaining GNU
--    General Public License terms still apply.
--
-- hdl_lib is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
-- You should have received a copy of the GNU General Public License
-- along with hdl_lib.  If not, see <http://www.gnu.org/licenses/>.
--
-- Author: Andre Souto (github.com/suoto) [DO NOT REMOVE]
-- Date: 2016/04/18 [DO NOT REMOVE]

---------------
-- Libraries --
---------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library exp_golomb_lib;
    use exp_golomb_lib.exp_golomb_pkg.all;

------------------------
-- Entity declaration --
------------------------
entity exp_golomb_encoder is
    generic (
        DATA_WIDTH   : integer  := 32);
    port (
        clk            : in  std_logic;
        clken          : in  std_logic;
        rst            : in  std_logic;

        -- Data input
        axi_in_tdata   : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        axi_in_tvalid  : in  std_logic;
        axi_in_tready  : out std_logic;

        -- Data output
        axi_out_tdata  : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        axi_out_tvalid : out std_logic;
        axi_out_tready : in  std_logic);
end exp_golomb_encoder;

architecture exp_golomb_encoder of exp_golomb_encoder is

    ---------------
    -- Constants --
    ---------------
    constant PIPE_DEPTH      : integer := 3;
    constant OUTPUT_SR_WIDTH : integer := 4*DATA_WIDTH;

    -----------
    -- Types --
    -----------
    type data_sr_type is
        array (natural range <>) of unsigned(DATA_WIDTH - 1 downto 0);

    type bin_width_sr is
        array (natural range <>) of unsigned(numbits(DATA_WIDTH) - 1 downto 0);

    -------------
    -- Signals --
    -------------
    signal data_valid_sr   : std_logic_vector(PIPE_DEPTH - 1 downto 0);
    signal data_sr         : data_sr_type(PIPE_DEPTH - 1 downto 1);
    signal data_width_sr   : bin_width_sr(PIPE_DEPTH - 1 downto 1);

    signal axi_in_tready_i : std_logic;

    -- Interface with the output adapting process
    signal encoded_data    : unsigned(2*DATA_WIDTH - 1 downto 0);
    signal encoded_dv      : std_logic;
    signal encoded_dwidth  : unsigned(2*numbits(DATA_WIDTH) - 1 downto 0);

    signal output_sr      : std_logic_vector(OUTPUT_SR_WIDTH - 1 downto 0);
    signal output_bit_cnt : unsigned(2*numbits(DATA_WIDTH) - 1 downto 0) := (others => '0');

begin

    -----------------------------
    -- Asynchronous assignments --
    -----------------------------
    axi_in_tready    <= axi_in_tready_i;
    data_valid_sr(0) <= '1' when axi_in_tvalid = '1' and axi_in_tready_i = '1' else
                        '0';

    ---------------
    -- Processes --
    ---------------
    -- Do the encoding itself in a pipeline fashion to improve timing
    encoding_p : process(clk)
        variable dwidth_int : integer; -- Helper to store the integer value of the
                                       -- calculated data width and make easier to
                                       -- index the data register
    begin
        if clk'event and clk = '1' then
            if clken = '1' then
                encoded_dv      <= '0';

                -- Shift the pipeline registers
                data_valid_sr(PIPE_DEPTH - 1 downto 1) <= data_valid_sr(PIPE_DEPTH - 2 downto 0);
                data_sr(PIPE_DEPTH - 1 downto 2)       <= data_sr(PIPE_DEPTH - 2 downto 1);
                data_width_sr(PIPE_DEPTH - 1 downto 2) <= data_width_sr(PIPE_DEPTH - 2 downto 1);

                -- Level 0 -- sample data and calculate its binary width
                if data_valid_sr(0) = '1' then
                    data_sr(1)       <= unsigned(axi_in_tdata) + 1;
                    data_width_sr(1) <= bin_width(unsigned(axi_in_tdata) + 1);
                end if;

                -- Level 1 -- Now we have all we need to convert
                --  - data_width_sr(1) has the binary width of the data
                if data_valid_sr(1) = '1' then
                    dwidth_int := to_integer(unsigned(data_width_sr(1)));

                    -- This is for simulation only, so the waveform will show the bits we
                    -- haven't assigned with Us
                    if IS_SIMULATION then
                        encoded_data <= (others => 'U'); 
                    end if;

                    encoded_data(dwidth_int - 1 downto 0) 
                        <= data_sr(1)(dwidth_int - 1 downto 0);

                    encoded_data(2*dwidth_int - 2 downto dwidth_int) 
                        <= (others => '0');

                    encoded_dwidth <= 2*data_width_sr(1) - 1;
                    encoded_dv     <= '1';

                end if;

            end if;
        end if;
    end process;

    -- The encoded data is a register whose width is DATA_WIDTH, but we won't get any
    -- actual compression unless we stream forward only the valid piece of data. In other
    -- words, we must join pieces of the encoded data until we have DATA_WIDTH valid
    -- bits.
    -- Note: we won't use pipeline signals from the encoding process because if the
    -- following algorithm is common it can be easily ported to a standalone module
    axi_output_adapting_p : process(clk)
    begin
        if clk'event and clk = '1' then
            if clken = '1' then
                axi_out_tvalid  <= '0';
                if output_bit_cnt < DATA_WIDTH - 1 then
                    axi_in_tready_i <= axi_out_tready;
                end if;


                if encoded_dv = '1' then
                    -- Runtime check for simulation only. It doesn't checks all values!
                    if IS_SIMULATION then
                        runtime_check(data_sr(2), encoded_data);
                    end if;

                    output_bit_cnt <= output_bit_cnt + encoded_dwidth;

                    output_sr <=
                        output_sr(OUTPUT_SR_WIDTH - to_integer(encoded_dwidth) - 1 downto 0) &
                                  std_logic_vector(encoded_data(to_integer(encoded_dwidth) - 1 downto 0));
                end if;

                -- OK, we have more bits than we need, so transmit what we have and 
                -- calculate how many bits will remain.
                -- One interesting thing is that if we get a sequence of large
                -- numbers we will have 'expansion' instead of compression. In these
                -- cases we must use backpressure to stop the data flow.
                -- Notice that we're at the end of the pipeline so we need to store
                -- some extra data until the data flow actually stops
                if output_bit_cnt > DATA_WIDTH then
                    if encoded_dv = '1' then
                        output_bit_cnt <= output_bit_cnt - DATA_WIDTH + encoded_dwidth;
                    else
                        output_bit_cnt <= output_bit_cnt - DATA_WIDTH;
                    end if;
                    axi_out_tvalid <= '1';
                    axi_out_tdata  <= output_sr(to_integer(output_bit_cnt) - 1
                                                downto
                                                to_integer(output_bit_cnt) - DATA_WIDTH);

                    if output_bit_cnt > 2*DATA_WIDTH - 1 then
                        axi_in_tready_i <= '0';
                    end if;

                end if;

                if rst = '1' then
                    axi_in_tready_i <= '0';
                    output_bit_cnt  <= (others => '0');
                end if;

            end if;
        end if;
    end process;

end exp_golomb_encoder;

