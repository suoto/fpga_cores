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
use work.interface_types_pkg.all;

------------------------
-- Entity declaration --
------------------------
entity axi_stream_debug is
  generic (
    TDATA_WIDTH        : integer := 32;
    TID_WIDTH          : integer := 0;
    FRAME_LENGTH_WIDTH : integer := 16; --sts.word_count'length;
    FRAME_COUNT_WIDTH  : integer := 16 --sts.frame_count'length;
);
  port (
    -- Usual ports
    clk           : in  std_logic;
    rst           : in  std_logic;
    -- Control and status
    cfg           : in  axi_stream_debug_cfg;
    sts           : out axi_stream_debug_sts(word_count(FRAME_LENGTH_WIDTH - 1 downto 0),
                                             frame_count(FRAME_COUNT_WIDTH - 1 downto 0),
                                             last_frame_length(FRAME_COUNT_WIDTH - 1 downto 0),
                                             min_frame_length(FRAME_COUNT_WIDTH - 1 downto 0),
                                             max_frame_length(FRAME_COUNT_WIDTH - 1 downto 0));
    -- AXI input
    s_tready      : out std_logic;
    s_tvalid      : in  std_logic;
    s_tlast       : in  std_logic;
    s_tdata       : in  std_logic_vector(TDATA_WIDTH - 1 downto 0) := (others => 'U');
    s_tid         : in  std_logic_vector(TID_WIDTH - 1 downto 0) := (others => 'U');
    -- AXI output
    m_tready      : in  std_logic;
    m_tvalid      : out std_logic;
    m_tlast       : out std_logic;
    m_tdata       : out std_logic_vector(TDATA_WIDTH - 1 downto 0);
    m_tid         : out std_logic_vector(TID_WIDTH - 1 downto 0));
end axi_stream_debug;

architecture axi_stream_debug of axi_stream_debug is

  -----------
  -- Types --
  -----------
  type ctrl_fsm_t is (run, block_data, wait_for_word, wait_for_last);

  -------------
  -- Signals --
  -------------
  signal cfg_delay         : axi_stream_debug_cfg;

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
  -- Add some delay to this to keep debug logic from influencing too much P&R
  cfg_delay_u : entity work.sr_delay
    generic map (
      DELAY_CYCLES  => 2,
      DATA_WIDTH    => 9,
      EXTRACT_SHREG => False)
    port map (
      clk   => clk,
      clken => '1',

      din(0) => cfg.clear_max_frame_length,
      din(1) => cfg.clear_min_frame_length,
      din(2) => cfg.clear_s_tvalid,
      din(3) => cfg.clear_s_tready,
      din(4) => cfg.clear_m_tvalid,
      din(5) => cfg.clear_m_tready,
      din(6) => cfg.block_data,
      din(7) => cfg.allow_word,
      din(8) => cfg.allow_frame,

      dout(0) => cfg_delay.clear_max_frame_length,
      dout(1) => cfg_delay.clear_min_frame_length,
      dout(2) => cfg_delay.clear_s_tvalid,
      dout(3) => cfg_delay.clear_s_tready,
      dout(4) => cfg_delay.clear_m_tvalid,
      dout(5) => cfg_delay.clear_m_tready,
      dout(6) => cfg_delay.block_data,
      dout(7) => cfg_delay.allow_word,
      dout(8) => cfg_delay.allow_frame);

  axi_flow_control_u : entity work.axi_stream_flow_control
    generic map ( DATA_WIDTH => TDATA_WIDTH + TID_WIDTH + 1 )
    port map (
      -- Usual ports
      enable   => enable,

      s_tvalid => s_tvalid,
      s_tready => s_tready_i,
      s_tdata  => s_tdata_agg,

      m_tvalid => m_tvalid_i,
      m_tready => m_tready,
      m_tdata  => m_tdata_agg);

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

  sts.frame_count <= std_logic_vector(frame_count);
  s_tready        <= s_tready_i;
  m_tvalid        <= m_tvalid_i;

  -- Assign internal frame length registers
  sts.word_count        <= std_logic_vector(word_count);
  sts.last_frame_length <= std_logic_vector(last_frame_length);
  sts.max_frame_length  <= std_logic_vector(max_frame_length);
  sts.min_frame_length  <= std_logic_vector(min_frame_length);

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
          if cfg_delay.block_data then
            ctrl_fsm <= block_data;
          end if;

        when block_data =>
          if cfg_delay.allow_word then
            ctrl_fsm <= wait_for_word;
          end if;
          if cfg_delay.allow_frame then
            ctrl_fsm <= wait_for_last;
          end if;

        when wait_for_word =>
          if s_data_valid then
            if cfg_delay.block_data then
              ctrl_fsm <= block_data;
            else
              ctrl_fsm <= run;
            end if;
          end if;

        when wait_for_last =>
          if s_last_valid then
            if cfg_delay.block_data then
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
      last_frame_length   <= (others => '0');
      max_frame_length    <= (others => '0');
      min_frame_length    <= (others => '1');
    elsif rising_edge(clk) then
      update_min_max    <= '0';

      if s_data_valid then
        word_count <= word_count + 1;
      end if;

      if s_last_valid then
        update_min_max    <= '1';
        frame_count       <= frame_count + 1;
        last_frame_length <= word_count + 1;
        word_count        <= (others => '0');
      end if;

      -- Update a cycle later
      if update_min_max then
        if last_frame_length > max_frame_length then
          max_frame_length <= last_frame_length;
        end if;
        if last_frame_length < min_frame_length then
          min_frame_length <= last_frame_length;
        end if;
      else
        if cfg_delay.clear_min_frame_length then
          min_frame_length <= (others => '1');
        end if;
        if cfg_delay.clear_max_frame_length then
          max_frame_length <= (others => '0');
        end if;
      end if;

    end if;
  end process;

  axi_strobe_monitor_block: block
    signal s_tvalid_latched : std_logic;
    signal s_tready_latched : std_logic;
    signal m_tvalid_latched : std_logic;
    signal m_tready_latched : std_logic;
  begin

    sts_strobes_delay_u : entity work.sr_delay
      generic map (
        DELAY_CYCLES  => 2,
        DATA_WIDTH    => 4,
        EXTRACT_SHREG => False)
      port map (
        clk    => clk,
        clken  => '1',

        din(0) => s_tvalid_latched,
        din(1) => s_tready_latched,
        din(2) => m_tvalid_latched,
        din(3) => m_tready_latched,

        dout(0) => sts.s_tvalid,
        dout(1) => sts.s_tready,
        dout(2) => sts.m_tvalid,
        dout(3) => sts.m_tready);

    axi_strobe_monitor_p : process(clk)
    begin
      if rising_edge(clk) then
        -- When clearing, use the current value
        if cfg_delay.clear_s_tvalid then
          s_tvalid_latched <= s_tvalid;
        else
          s_tvalid_latched <= s_tvalid or s_tvalid_latched;
        end if;

        if cfg_delay.clear_s_tready then
          s_tready_latched <= s_tready_i;
        else
          s_tready_latched <= s_tready_i or s_tready_latched;
        end if;

        if cfg_delay.clear_m_tvalid then
          m_tvalid_latched <= m_tvalid_i;
        else
          m_tvalid_latched <= m_tvalid_i or m_tvalid_latched;
        end if;

        if cfg_delay.clear_m_tready then
          m_tready_latched <= m_tready;
        else
          m_tready_latched <= m_tready or m_tready_latched;
        end if;

      end if;
    end process;
  end block;

end axi_stream_debug;
