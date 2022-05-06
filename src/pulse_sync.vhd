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

-- Synchronizes a pulse between different clock domains
entity pulse_sync is
    generic (
        EXTRA_DELAY_CYCLES : natural := 1);
    port (
        -- Usual ports
        src_clk     : in  std_logic;
        src_clken   : in  std_logic;
        src_pulse   : in  std_logic;

        dst_clk     : in  std_logic; 
        dst_clken   : in  std_logic;
        dst_pulse   : out std_logic);
end pulse_sync;

architecture pulse_sync of pulse_sync is

    -------------
    -- Signals --
    -------------
    signal pulse_toggle : std_logic := '0';

begin

    -------------------
    -- Port mappings --
    -------------------
    dst_pulse_t : entity work.edge_detector
        generic map (
            SYNCHRONIZE_INPUT => True,
            OUTPUT_DELAY      => EXTRA_DELAY_CYCLES)
        port map (
            -- Usual ports
            clk     => dst_clk,
            clken   => dst_clken,
    
            -- 
            din     => pulse_toggle,
            -- Edges detected
            rising  => open, 
            falling => open, 
            toggle  => dst_pulse);
    
    ---------------
    -- Processes --
    ---------------
    process(src_clk)
    begin
        if src_clk'event and src_clk = '1' then
            if src_clken = '1' then
                if src_pulse = '1' then
                    pulse_toggle <= not pulse_toggle;
                end if;
            end if;
        end if;
    end process;

end pulse_sync;

