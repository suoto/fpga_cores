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
entity axi_stream_frame_padder is
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
end axi_stream_frame_padder;

architecture axi_stream_frame_padder of axi_stream_frame_padder is

  -------------
  -- Signals --
  -------------
  signal s_tready_i       : std_logic;
  signal m_tvalid_i       : std_logic;
  signal s_axi_dv         : std_logic;
  signal m_axi_dv         : std_logic;
  signal m_tlast_i        : std_logic;
  signal pad_frame        : std_logic;
  signal frame_length_reg : unsigned(FRAME_LENGTH_WIDTH - 1 downto 0);
  signal length_count     : unsigned(FRAME_LENGTH_WIDTH - 1 downto 0);

begin

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  -- Slave and master strobes
  s_axi_dv   <= s_tvalid and s_tready_i;
  m_axi_dv   <= m_tvalid_i and m_tready;

  -- Force not ready when we're padding
  s_tready_i <= m_tready and not pad_frame;

  m_tvalid_i <= '1' when pad_frame else s_tvalid;
  m_tdata    <= s_tdata and (TDATA_WIDTH - 1 downto 0 => not pad_frame) when m_tvalid_i else
                (others => 'U');

  m_tlast_i  <= '1' when length_count >= frame_length_reg else '0';

  -- Internal only
  s_tready   <= s_tready_i;
  m_tvalid   <= m_tvalid_i;
  m_tlast    <= m_tlast_i when m_tvalid_i else 'U';

  ---------------
  -- Processes --
  ---------------
  process(clk, rst)
  begin
    if rst then
      -- Start length count at 1 instead of zero so we can compare with frame_length
      -- without having to subtract one
      length_count <= (0 => '1', others => '0');
      pad_frame    <= '0';
    elsif clk'event and clk = '1' then
      if s_axi_dv then
        if s_tlast = '1' and length_count < unsigned(frame_length) then
          pad_frame <= '1';
        end if;
      end if;

      if m_axi_dv then
        if m_tlast_i then
          -- Start length count at 1 instead of zero so we can compare with frame_length
          -- without having to subtract one
          length_count <= (0 => '1', others => '0');
          pad_frame    <= '0';
        else
          length_count <= length_count + 1;
        end if;
      end if;
    end if;
  end process;


  -- Need to sample frame length because after the frame has completed there's
  -- no guarantee it will remain constant
  frame_length_p : block
    signal first_word           : std_logic;
    signal frame_length_sampled : unsigned(FRAME_LENGTH_WIDTH - 1 downto 0);
  begin
    frame_length_reg <= unsigned(frame_length) when first_word else frame_length_sampled;
    process(clk, rst)
    begin
      if rst then
        first_word <= '1';
      elsif rising_edge(clk) then
        if m_axi_dv then
          first_word <= m_tlast_i;
          if first_word then
            frame_length_sampled <= unsigned(frame_length);
          end if;
        end if;
      end if;
    end process;
  end block;

end axi_stream_frame_padder;
