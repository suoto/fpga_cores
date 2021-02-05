--
-- FPGA Cores -- A(nother) HDL library
--
-- Copyright 2016 by Andre Souto (suoto)
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
entity axi_stream_demux is
  generic (
    INTERFACES : positive := 1;
    DATA_WIDTH : natural := 1);
  port (
    selection_mask : in std_logic_vector(INTERFACES - 1 downto 0);

    s_tvalid       : in  std_logic;
    s_tready       : out std_logic;
    s_tdata        : in  std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => 'U');

    m_tvalid       : out std_logic_vector(INTERFACES - 1 downto 0);
    m_tready       : in  std_logic_vector(INTERFACES - 1 downto 0);
    m_tdata        : out std_logic_array_t(INTERFACES - 1 downto 0)(DATA_WIDTH - 1 downto 0)

  );
end axi_stream_demux;

architecture axi_stream_demux of axi_stream_demux is

  -----------
  -- Types --
  -----------
  type din_t is array (natural range <>) of std_logic_vector(DATA_WIDTH - 1 downto 0);

  -------------
  -- Signals --
  -------------
  signal selection_int : integer range 0 to INTERFACES - 1;
  signal m_tvalid_i    : std_logic_vector(INTERFACES - 1 downto 0);

begin

  -------------------
  -- Port mappings --
  -------------------

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  selection_int  <= to_integer(one_hot_to_decimal(selection_mask));

  m_tvalid   <= m_tvalid_i;
  m_tvalid_i <= (INTERFACES - 1 downto 0 => s_tvalid) and selection_mask;

  s_tready <= m_tready(selection_int);

  g_mtdata : for i in 0 to INTERFACES - 1 generate
    m_tdata(i) <= (others => 'U') when m_tvalid_i(i) = '0' else s_tdata;
  end generate;

end axi_stream_demux;

