--
-- FPGA Cores -- An HDL core library
--
-- Copyright 2020 by Andre Souto (suoto)
--
-- This file is part of FPGA Cores.
-- 
-- FPGA Cores is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
-- 
-- FPGA Cores is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with FPGA Cores.  If not, see <http://www.gnu.org/licenses/>.

library ieee;
use ieee.std_logic_1164.all;

package axi_pkg is

  type axi_stream_qualified_data_t is record
    tdata  : std_logic_vector;
    tkeep  : std_logic_vector;
    tuser  : std_logic_vector;
    tvalid : std_logic;
    tready : std_logic;
    tlast  : std_logic;
  end record;

  type axi_stream_bus_t is record
    tdata  : std_logic_vector;
    tuser  : std_logic_vector;
    tvalid : std_logic;
    tready : std_logic;
    tlast  : std_logic;
  end record;

  type axi_stream_data_bus_t is record
    tdata  : std_logic_vector;
    tvalid : std_logic;
    tready : std_logic;
    tlast  : std_logic;
  end record;

end package axi_pkg;
