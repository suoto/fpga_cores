--
-- FPGA core library
--
-- Copyright 2021 by Andre Souto (suoto)
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
entity axi_stream_debug is
  generic (
    TDATA_WIDTH        : integer := 32;
    TID_WIDTH          : integer := 0;
    FRAME_COUNT_WIDTH  : integer := 8;
    FRAME_LENGTH_WIDTH : integer := 8);
  port (
    -- Usual ports
    clk                   : in  std_logic;
    rst                   : in  std_logic;
    -- Control and status
    cfg_reset_min_max     : in  std_logic;
    cfg_block_data        : in std_logic;
    cfg_allow_word        : in std_logic;
    cfg_allow_frame       : in std_logic;
    sts_frame_count       : out std_logic_vector(FRAME_COUNT_WIDTH - 1 downto 0);
    sts_last_frame_length : out std_logic_vector(FRAME_LENGTH_WIDTH - 1 downto 0);
    sts_min_frame_length  : out std_logic_vector(FRAME_LENGTH_WIDTH - 1 downto 0);
    sts_max_frame_length  : out std_logic_vector(FRAME_LENGTH_WIDTH - 1 downto 0);
    -- AXI input
    s_tready              : out std_logic;
    s_tvalid              : in  std_logic;
    s_tlast               : in  std_logic;
    s_tdata               : in  std_logic_vector(TDATA_WIDTH - 1 downto 0) := (others => 'U');
    s_tid                 : in  std_logic_vector(TID_WIDTH - 1 downto 0) := (others => 'U');
    -- AXI output
    m_tready              : in  std_logic;
    m_tvalid              : out std_logic;
    m_tlast               : out std_logic;
    m_tdata               : out std_logic_vector(TDATA_WIDTH - 1 downto 0);
    m_tid                 : out std_logic_vector(TID_WIDTH - 1 downto 0));
end axi_stream_debug;

architecture axi_stream_debug of axi_stream_debug is

  -----------
  -- Types --
  -----------
  type ctrl_fsm_t is (run, block_data, wait_for_word, wait_for_last);

  -------------
  -- Signals --
  -------------
  signal ctrl_fsm          : ctrl_fsm_t := run;
  signal enable            : std_logic;
  signal s_data_valid      : std_logic;
  signal s_last_valid      : std_logic;

  signal s_tdata_agg       : std_logic_vector(TDATA_WIDTH + TID_WIDTH downto 0);
  signal m_tdata_agg       : std_logic_vector(TDATA_WIDTH + TID_WIDTH downto 0);

  signal frame_count       : unsigned(FRAME_COUNT_WIDTH - 1 downto 0);
  signal word_count        : unsigned(FRAME_LENGTH_WIDTH - 1 downto 0);
  signal update_min_max    : std_logic;
  -- If a frame is going through, schedule a reset after it's completed
  signal last_frame_length : unsigned(FRAME_LENGTH_WIDTH - 1 downto 0);
  signal min_frame_length  : unsigned(FRAME_LENGTH_WIDTH - 1 downto 0);
  signal max_frame_length  : unsigned(FRAME_LENGTH_WIDTH - 1 downto 0);

  signal s_tready_i        : std_logic;
  signal m_tvalid_i        : std_logic;

begin

  -------------------
  -- Port mappings --
  -------------------
  -- Use a 1 to 1 mux for the low level AXI flow control
  axi_ctrl_u : entity work.axi_stream_mux
    generic map (
      INTERFACES => 1,
      DATA_WIDTH => TDATA_WIDTH + TID_WIDTH + 1)
    port map (
      selection_mask(0) => enable,

      s_tvalid(0) => s_tvalid,
      s_tready(0) => s_tready_i,
      s_tdata(0)  => s_tdata_agg,

      m_tvalid    => m_tvalid_i,
      m_tready    => m_tready,
      m_tdata     => m_tdata_agg);

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  enable          <= '1' when ctrl_fsm /= block_data else '0';

  s_tdata_agg     <= s_tlast & s_tid & s_tdata;

  m_tdata         <= m_tdata_agg(TDATA_WIDTH - 1 downto 0) when m_tvalid_i else (others => 'U');
  m_tid           <= m_tdata_agg(TDATA_WIDTH + TID_WIDTH - 1 downto TDATA_WIDTH) when m_tvalid_i else (others => 'U');
  m_tlast         <= m_tdata_agg(TDATA_WIDTH + TID_WIDTH) and m_tvalid_i;

  s_data_valid    <= s_tvalid and s_tready_i;
  s_last_valid    <= s_data_valid and s_tlast;

  sts_frame_count <= std_logic_vector(frame_count);
  s_tready        <= s_tready_i;
  m_tvalid        <= m_tvalid_i;

  -- Assign internal frame length registers
  sts_last_frame_length <= std_logic_vector(last_frame_length);
  sts_max_frame_length  <= std_logic_vector(max_frame_length);
  sts_min_frame_length  <= std_logic_vector(min_frame_length);

  ---------------
  -- Processes --
  ---------------
  flow_cntrl_p : process(clk, rst)
  begin
    if rst then
      ctrl_fsm <= run;
    elsif rising_edge(clk) then
      case ctrl_fsm is
        when run =>
          if cfg_block_data then
            ctrl_fsm <= block_data;
          end if;

        when block_data =>
          if cfg_allow_word then
            ctrl_fsm <= wait_for_word;
          end if;
          if cfg_allow_frame then
            ctrl_fsm <= wait_for_last;
          end if;

        when wait_for_word =>
          if s_data_valid then
            if cfg_block_data then
              ctrl_fsm <= block_data;
            else
              ctrl_fsm <= run;
            end if;
          end if;

        when wait_for_last =>
          if s_last_valid then
            if cfg_block_data then
              ctrl_fsm <= block_data;
            else
              ctrl_fsm <= run;
            end if;
          end if;
      end case;
    end if;
  end process;

  sts_count_p : process(clk, rst)
  begin
    if rst then
      update_min_max      <= '0';

      frame_count         <= (others => '0');
      word_count          <= (others => '0');
      max_frame_length    <= (others => '0');
      min_frame_length    <= (others => '1');
    elsif rising_edge(clk) then
      update_min_max    <= '0';

      if s_data_valid then
        word_count <= word_count + 1;
      end if;

      if s_last_valid then
        frame_count       <= frame_count + 1;
        last_frame_length <= word_count + 1;
        update_min_max    <= '1';
      end if;

      -- Update a cycle later
      if update_min_max then
        if last_frame_length > max_frame_length then
          max_frame_length <= last_frame_length;
        end if;
        if last_frame_length < min_frame_length then
          min_frame_length <= last_frame_length;
        end if;
      end if;

      -- If a reset comes in at the same time as an update request, use the update values
      -- as reset value
      if cfg_reset_min_max then
        if update_min_max then
          max_frame_length <= last_frame_length;
          min_frame_length <= last_frame_length;
        else
          max_frame_length    <= (others => '0');
          min_frame_length    <= (others => '1');
        end if;
      else
      end if;
    end if;
  end process;

end axi_stream_debug;
