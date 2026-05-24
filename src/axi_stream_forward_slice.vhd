--
-- FPGA core library
--
-- Copyright 2019-2021 by Andre Souto (suoto)
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
entity axi_stream_forward_slice is
    generic (
        TDATA_WIDTH : integer
    );
    port (
        -- Usual ports
        clk     : in  std_logic;
        rst     : in  std_logic;

        -- AXI slave input
        s_tvalid : in  std_logic;
        s_tready : out std_logic;
        s_tdata  : in  std_logic_vector(TDATA_WIDTH - 1 downto 0);

        -- AXI master output
        m_tvalid : out std_logic;
        m_tready : in  std_logic;
        m_tdata  : out std_logic_vector(TDATA_WIDTH - 1 downto 0)
    );
end axi_stream_forward_slice;

architecture axi_stream_forward_slice of axi_stream_forward_slice is
begin

  s_tready <= m_tready or not m_tvalid;

  process(clk, rst)
  begin
    if rst = '1' then
      m_tvalid <= '0';
    elsif rising_edge(clk) then
      if m_tready then
        m_tvalid <= '0';
        -- Force m_tdata for Xs to make sure data is not used when m_tvalid is
        -- 0
        m_tdata  <= (others => 'X');
      end if;

      if s_tvalid and s_tready then
        m_tvalid <= '1';
        m_tdata  <= s_tdata;
      end if;
    end if;
  end process;

end architecture axi_stream_forward_slice;
