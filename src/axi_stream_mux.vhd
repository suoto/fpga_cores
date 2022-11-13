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
  signal m_tdata_mux : std_logic_vector(DATA_WIDTH - 1 downto 0);
begin

  s_tready        <= selection_mask and (INTERFACES - 1 downto 0 => m_tready);
  m_tdata         <= (others => 'U') when has_undefined(selection_mask) or or(selection_mask) = '0' else m_tdata_mux;
  m_tvalid        <= '0'             when has_undefined(selection_mask) or or(selection_mask) = '0' else or(s_tvalid and selection_mask);

  process(s_tdata, selection_mask)
    variable result : std_logic_vector(DATA_WIDTH - 1 downto 0);
  begin
    result := (others => '0');
    for i in 0 to INTERFACES - 1 loop
      result := result or ( s_tdata(i) and ( DATA_WIDTH - 1 downto 0 => selection_mask( i ) ) );
    end loop;
    m_tdata_mux <= result;
  end process;

end axi_stream_mux;
