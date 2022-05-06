--
-- FPGA core library
--
-- Copyright 2014-2022 by Andre Souto (suoto)
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
-- This module slice_frames AXI Stream frames to the specified length. Smaller frames
-- pass through unmodified

---------------
-- Libraries --
---------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

------------------------
-- Entity declaration --
------------------------
entity axi_stream_frame_slicer is
  generic (
    FRAME_LENGTH_WIDTH : integer := 8;
    TDATA_WIDTH        : integer := 1);
  port (
    -- Usual ports
    clk          : in  std_logic;
    rst          : in  std_logic;

    frame_length : in std_logic_vector(FRAME_LENGTH_WIDTH - 1 downto 0);

    -- Input stream
    s_tvalid     : in  std_logic;
    s_tready     : out std_logic;
    s_tdata      : in  std_logic_vector(TDATA_WIDTH - 1 downto 0);
    s_tlast      : in  std_logic;

    -- Output stream
    m_tvalid     : out std_logic;
    m_tready     : in  std_logic;
    m_tdata      : out std_logic_vector(TDATA_WIDTH - 1 downto 0);
    m_tlast      : out std_logic);
end axi_stream_frame_slicer;

architecture axi_stream_frame_slicer of axi_stream_frame_slicer is

  -------------
  -- Signals --
  -------------
  signal axi_dv       : std_logic;
  signal m_tlast_i    : std_logic;
  signal length_count : unsigned(FRAME_LENGTH_WIDTH - 1 downto 0);

begin

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  axi_dv  <= s_tvalid and m_tready;

  m_tvalid  <= s_tvalid;
  s_tready  <= m_tready;
  m_tdata   <= s_tdata;

  -- m_tlast_i <= '1' when length_count = unsigned(frame_length) - 1 else '0';
  m_tlast_i <= s_tlast when length_count < unsigned(frame_length) - 1 else '1';
  m_tlast   <= m_tlast_i when s_tvalid else 'U';

  ---------------
  -- Processes --
  ---------------
  process(clk, rst)
  begin
    if rst = '1' then
      length_count <= (others => '0');
    elsif clk'event and clk = '1' then
      if axi_dv then
        if m_tlast_i then
          length_count <= (others => '0');
        else
          length_count <= length_count + 1;
        end if;
      end if;
    end if;
  end process;

end axi_stream_frame_slicer;
