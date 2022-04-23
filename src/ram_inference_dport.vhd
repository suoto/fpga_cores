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
entity ram_inference_dport is
    generic (
        DEPTH        : natural := 16;
        DATA_WIDTH   : natural := 16;
        OUTPUT_DELAY : natural := 1);
    port (
        -- Port A
        clk_a     : in  std_logic;
        clken_a   : in  std_logic;
        wren_a    : in  std_logic;
        addr_a    : in  std_logic_vector(numbits(DEPTH) - 1 downto 0);
        wrdata_a  : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        rddata_a  : out std_logic_vector(DATA_WIDTH - 1 downto 0);

        -- Port B
        clk_b     : in  std_logic;
        clken_b   : in  std_logic;
        wren_b    : in  std_logic;
        addr_b    : in  std_logic_vector(numbits(DEPTH) - 1 downto 0);
        wrdata_b  : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        rddata_b  : out std_logic_vector(DATA_WIDTH - 1 downto 0));
end ram_inference_dport;

architecture ram_inference_dport of ram_inference_dport is

    -----------
    -- Types --
    -----------
    type data_type is array (natural range <>) of std_logic_vector(DATA_WIDTH - 1 downto 0);

    -------------
    -- Signals --
    -------------
    shared variable ram : data_type(DEPTH - 1 downto 0);
    signal rddata_a_i   : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal rddata_b_i   : std_logic_vector(DATA_WIDTH - 1 downto 0);

begin

    -------------------
    -- Port mappings --
    -------------------

    ------------------------------
    -- Asynchronous assignments --
    ------------------------------
    rddata_a_delay : entity work.sr_delay
        generic map (
            DELAY_CYCLES => OUTPUT_DELAY,
            DATA_WIDTH   => DATA_WIDTH)
        port map (
            clk     => clk_a,
            clken   => clken_a,

            din     => rddata_a_i,
            dout    => rddata_a);

    rddata_b_delay : entity work.sr_delay
        generic map (
            DELAY_CYCLES => OUTPUT_DELAY,
            DATA_WIDTH   => DATA_WIDTH)
        port map (
            clk     => clk_b,
            clken   => clken_b,

            din     => rddata_b_i,
            dout    => rddata_b);

    ---------------
    -- Processes --
    ---------------
    port_a : process(clk_a)
    begin
        if clk_a'event and clk_a = '1' then
            if clken_a = '1' then
                if wren_a = '1' then
                    ram(to_integer(unsigned(addr_a))) := wrdata_a;
                end if;
                rddata_a_i <= ram(to_integer(unsigned(addr_a)));
            end if;
        end if;
    end process;

    port_b : process(clk_b)
    begin
        if clk_b'event and clk_b = '1' then
            if clken_b = '1' then
                if wren_b = '1' then
                    ram(to_integer(unsigned(addr_b))) := wrdata_b;
                end if;
                rddata_b_i <= ram(to_integer(unsigned(addr_b)));
            end if;
        end if;
    end process;

end ram_inference_dport;

