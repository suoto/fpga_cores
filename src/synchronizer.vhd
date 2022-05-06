--
-- FPGA core library
--
-- Copyright 2014-2021 by Andre Souto (suoto)
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

-- Synchronizes a data bus between different clock domains
entity synchronizer is
    generic (
        SYNC_STAGES  : natural := 2;
        DATA_WIDTH   : integer := 1);
    port (
        -- Usual ports
        clk     : in  std_logic;
        clken   : in  std_logic := '1';

        -- Block specifics
        din     : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        dout    : out std_logic_vector(DATA_WIDTH - 1 downto 0));
end synchronizer;

architecture synchronizer of synchronizer is

    -----------
    -- Types --
    -----------
    type din_t is array (natural range <>) of std_logic_vector(DATA_WIDTH - 1 downto 0);

    -------------
    -- Signals --
    -------------
    signal din_sr   : din_t(SYNC_STAGES - 1 downto 0);

    ----------------
    -- Attributes --
    ----------------
    -- Synplify Pro: disable shift-register LUT (SRL) extraction
    attribute syn_srlstyle : string;
    attribute syn_srlstyle of din_sr : signal is "registers";

    -- Xilinx XST: disable shift-register LUT (SRL) extraction
    attribute shreg_extract : string;
    attribute shreg_extract of din_sr : signal is "no";

    -- Disable X propagation during timing simulation. In the event of 
    -- a timing violation, the previous value is retained on the output instead 
    -- of going unknown (see Xilinx UG625)
    attribute ASYNC_REG : string;
    attribute ASYNC_REG of din_sr : signal is "TRUE";

begin

    -------------------
    -- Port mappings --
    -------------------

    ------------------------------
    -- Asynchronous assignments --
    ------------------------------
    dout   <= din_sr(SYNC_STAGES - 1);

    ---------------
    -- Processes --
    ---------------
    process(clk)
    begin
        if clk'event and clk = '1' then
            if clken = '1' then
                din_sr <= din_sr(SYNC_STAGES - 2 downto 0) & din;
            end if;
        end if;
    end process;


end synchronizer;

