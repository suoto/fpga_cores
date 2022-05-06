--
-- FPGA core library
--
-- Copyright 2016-2022 by Andre Souto (suoto)
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
    m_tdata        : out std_logic_array_t(INTERFACES - 1 downto 0)(DATA_WIDTH - 1 downto 0));
end axi_stream_demux;

architecture axi_stream_demux of axi_stream_demux is

  -------------
  -- Signals --
  -------------
  signal selection_int : integer range 0 to INTERFACES - 1;
  signal m_tvalid_i    : std_logic_vector(INTERFACES - 1 downto 0);

begin

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  selection_int <= to_integer(one_hot_to_decimal(selection_mask));

  m_tvalid      <= m_tvalid_i;
  m_tvalid_i    <= (INTERFACES - 1 downto 0 => s_tvalid) and selection_mask;

  s_tready      <= m_tready(selection_int) and or(selection_mask);

  g_mtdata : for i in 0 to INTERFACES - 1 generate
    m_tdata(i) <= (others => 'U') when m_tvalid_i(i) = '0' else s_tdata;
  end generate;

end axi_stream_demux;

