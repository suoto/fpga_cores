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

------------------------
-- Entity declaration --
------------------------
entity axi_stream_duplicate is
  generic ( TDATA_WIDTH : integer  := 8 );
  port (
    -- Usual ports
    clk       : in  std_logic;
    rst       : in  std_logic;

    -- AXI stream input
    s_tready  : out std_logic;
    s_tdata   : in  std_logic_vector(TDATA_WIDTH - 1 downto 0);
    s_tvalid  : in  std_logic;
    -- AXI stream output 0
    m0_tready : in  std_logic;
    m0_tdata  : out std_logic_vector(TDATA_WIDTH - 1 downto 0);
    m0_tvalid : out std_logic;
    -- AXI stream output 1
    m1_tready : in  std_logic;
    m1_tdata  : out std_logic_vector(TDATA_WIDTH - 1 downto 0);
    m1_tvalid : out std_logic);
end axi_stream_duplicate;

architecture axi_stream_duplicate of axi_stream_duplicate is

  -------------
  -- Signals --
  -------------
  signal s_axi_dv    : std_logic;
  signal m0_axi_dv   : std_logic;
  signal m1_axi_dv   : std_logic;

  -- Outputs
  signal s_tready_i  : std_logic;
  signal m0_tvalid_i : std_logic;
  signal m1_tvalid_i : std_logic;

begin

  -------------------
  -- Port mappings --
  -------------------

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  s_tready_i <= m0_tready and m1_tready;

  s_axi_dv <= '1' when s_tvalid = '1' and s_tready_i = '1' else '0';

  m0_axi_dv <= '1' when m0_tvalid_i = '1' and m0_tready = '1' else '0';
  m1_axi_dv <= '1' when m1_tvalid_i = '1' and m1_tready = '1' else '0';

  s_tready  <= s_tready_i;
  m0_tvalid <= m0_tvalid_i;
  m1_tvalid <= m1_tvalid_i;

  ---------------
  -- Processes --
  ---------------
  process(clk, rst)
  begin
    if rst = '1' then
      m0_tvalid_i <= '0';
      m1_tvalid_i <= '0';
      m0_tdata    <= (others => 'U');
      m1_tdata    <= (others => 'U');
    elsif clk'event and clk = '1' then
      if m0_axi_dv = '1' then
        m0_tvalid_i <= '0';
        m0_tdata    <= (others => 'U');
      end if;

      if m1_axi_dv = '1' then
        m1_tvalid_i <= '0';
        m1_tdata    <= (others => 'U');
      end if;

      if s_axi_dv = '1' then
        m0_tvalid_i <= '1';
        m1_tvalid_i <= '1';
        m0_tdata    <= s_tdata;
        m1_tdata    <= s_tdata;
      end if;
    end if;
  end process;

end axi_stream_duplicate;
