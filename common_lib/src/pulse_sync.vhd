--
-- hdl_lib -- An HDL core library
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
-- hdl_lib is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License
-- along with hdl_lib.  If not, see <http://www.gnu.org/licenses/>.

library ieee;
    use ieee.std_logic_1164.all;  

library common_lib;

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
    dst_pulse_t : entity common_lib.edge_detector
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

