--
-- FPGA Cores -- An HDL core library
--
-- Copyright 2014-2016 by Andre Souto (suoto)
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

---------------
-- Libraries --
---------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library fpga_cores;
use fpga_cores.common_pkg.all;

------------------------
-- Entity declaration --
------------------------
entity axi_stream_mux is
  generic (
    INTERFACES : positive := 1;
    DATA_WIDTH : positive := 1);
  port (
    selection_mask : in std_logic_vector(INTERFACES - 1 downto 0);

    s_tvalid       : in  std_logic_vector(INTERFACES - 1 downto 0);
    s_tready       : out std_logic_vector(INTERFACES - 1 downto 0);
    s_tdata        : in  std_logic_array_t(INTERFACES - 1 downto 0)(DATA_WIDTH - 1 downto 0) := (others => (others => 'U'));

    m_tvalid       : out std_logic;
    m_tready       : in  std_logic;
    m_tdata        : out std_logic_vector(DATA_WIDTH - 1 downto 0));
end axi_stream_mux;

architecture axi_stream_mux of axi_stream_mux is
  signal selection_int   : integer range 0 to INTERFACES - 1;
  signal selection_valid : std_logic;
begin

  -- Block data if selection mask is all 0s
  selection_valid <= or(selection_mask);

  selection_int   <= to_integer(one_hot_to_decimal(selection_mask));
  m_tdata         <= (others => 'U') when has_undefined(selection_mask) or selection_valid = '0' else s_tdata(selection_int);

  m_tvalid        <= '0' when has_undefined(selection_mask) or selection_valid = '0' else s_tvalid(selection_int);
  s_tready        <= selection_mask and (INTERFACES - 1 downto 0 => m_tready and selection_valid);

end axi_stream_mux;

