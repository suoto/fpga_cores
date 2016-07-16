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

library	ieee;
    use ieee.std_logic_1164.all;  

-- Shit register based delay --
entity sr_delay is
    generic (
        DELAY_CYCLES : natural := 1;
        DATA_WIDTH   : positive := 1);
    port (
        clk     : in  std_logic;
        clken   : in  std_logic;

        din     : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        dout    : out std_logic_vector(DATA_WIDTH - 1 downto 0));
end sr_delay;

architecture sr_delay of sr_delay is

    -----------
    -- Types --
    -----------
    type din_t is array (natural range <>) of std_logic_vector(DATA_WIDTH - 1 downto 0);

    -------------
    -- Signals --
    -------------
    signal din_sr   : din_t(DELAY_CYCLES - 1 downto 0);

begin

    ------------------------------
    -- Asynchronous assignments --
    ------------------------------
    zd : if DELAY_CYCLES = 0 generate
        dout <= din;
    end generate zd;

    nzd : if DELAY_CYCLES > 0 generate
        dout <= din_sr(DELAY_CYCLES - 1);
    end generate nzd;

    ---------------
    -- Processes --
    ---------------
    nzd_p : if DELAY_CYCLES > 0 generate
        process(clk)
        begin
            if clk'event and clk = '1' then
                if clken = '1' then
                    din_sr  <= din_sr(DELAY_CYCLES - 2 downto 0) & din;
                end if;
            end if;
        end process;
    end generate nzd_p;

end sr_delay;

