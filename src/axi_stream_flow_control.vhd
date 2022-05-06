--
-- FPGA core library
--
-- Copyright 2020-2021 by Andre Souto (suoto)
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


---------------
-- Libraries --
---------------
library ieee;
use ieee.std_logic_1164.all;

------------------------
-- Entity declaration --
------------------------
entity axi_stream_flow_control is
  generic ( DATA_WIDTH : integer  := 1 );
  port (
    -- Usual ports
    enable   : in  std_logic;

    s_tvalid : in  std_logic;
    s_tready : out std_logic;
    s_tdata  : in  std_logic_vector(DATA_WIDTH - 1 downto 0);

    m_tvalid : out std_logic;
    m_tready : in  std_logic;
    m_tdata  : out std_logic_vector(DATA_WIDTH - 1 downto 0));
end axi_stream_flow_control;

architecture axi_stream_flow_control of axi_stream_flow_control is

  signal m_tvalid_i : std_logic;

begin

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  m_tvalid   <= m_tvalid_i;
  m_tvalid_i <= enable and s_tvalid;
  s_tready   <= enable and m_tready;
  m_tdata    <= s_tdata when m_tvalid_i = '1' else (others => 'U');

end axi_stream_flow_control;

