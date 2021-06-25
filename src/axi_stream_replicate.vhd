--
-- FPGA core library
--
-- Copyright 2016 by Andre Souto (suoto)
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

-- Replicate a single stream to multiple targets

library ieee;
use ieee.std_logic_1164.all;

use work.common_pkg.all;

------------------------
-- Entity declaration --
------------------------
entity axi_stream_replicate is
  generic (
    INTERFACES  : integer := 2;
    TDATA_WIDTH : integer := 8
  );
  port (
    -- Usual ports
    clk       : in  std_logic;
    rst       : in  std_logic;

    -- AXI stream input
    s_tvalid  : in  std_logic;
    s_tready  : out std_logic;
    s_tdata   : in  std_logic_vector(TDATA_WIDTH - 1 downto 0);
    -- AXI stream outputs
    m_tvalid  : out std_logic_vector(INTERFACES - 1 downto 0);
    m_tready  : in  std_logic_vector(INTERFACES - 1 downto 0);
    m_tdata   : out std_logic_array_t(INTERFACES - 1 downto 0)(TDATA_WIDTH - 1 downto 0));
end axi_stream_replicate;

architecture axi_stream_replicate of axi_stream_replicate is

  -------------
  -- Signals --
  -------------
  signal s_axi_dv       : std_logic;
  signal m_axi_dv       : std_logic_vector(INTERFACES - 1 downto 0);

  signal s_tready_i     : std_logic;
  signal m_tvalid_i     : std_logic_vector(INTERFACES - 1 downto 0);

  signal interface_done : std_logic_vector(INTERFACES - 1 downto 0);

begin

  -------------------
  -- Port mappings --
  -------------------

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  s_axi_dv   <= '1' when s_tvalid = '1' and s_tready_i = '1' else '0';
  m_axi_dv   <= m_tvalid_i and m_tready;

  -- Assert s_tready whenever we've sent data on all interfaces but use
  -- m_axi_dv to allow back to back transfers
  s_tready_i <= and(interface_done or m_axi_dv);

  m_tvalid_i <= (INTERFACES - 1 downto 0 => s_tvalid) and not interface_done;

  g_tdata : for i in 0 to INTERFACES - 1 generate
    m_tdata(i) <= s_tdata when m_tvalid_i(i) = '1' else (others => 'U');
  end generate;

  s_tready   <= s_tready_i;
  m_tvalid   <= m_tvalid_i;

  ---------------
  -- Processes --
  ---------------
  process(clk, rst)
  begin
    if rst = '1' then
      interface_done <= (others => '0');
    elsif clk'event and clk = '1' then
      interface_done <= interface_done or m_axi_dv;

      if s_axi_dv = '1' then
        interface_done <= (others => '0');
      end if;
    end if;
  end process;

end axi_stream_replicate;
