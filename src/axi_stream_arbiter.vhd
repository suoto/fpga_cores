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
entity axi_stream_arbiter is
  generic (
    MODE            : string   := "ROUND_ROBIN"; -- ROUND_ROBIN, INTERLEAVED, ABSOLUTE
    INTERFACES      : positive := 1;
    DATA_WIDTH      : positive := 1;
    REGISTER_INPUTS : boolean  := False);
  port (
    -- Usual ports
    clk              : in  std_logic;
    rst              : in  std_logic;

    selected         : out std_logic_vector(INTERFACES - 1 downto 0);
    selected_encoded : out std_logic_vector(numbits(INTERFACES) - 1 downto 0);

    -- AXI slave input
    s_tvalid         : in  std_logic_vector(INTERFACES - 1 downto 0);
    s_tready         : out std_logic_vector(INTERFACES - 1 downto 0);
    s_tdata          : in  std_logic_array_t(INTERFACES - 1 downto 0)(DATA_WIDTH - 1 downto 0);
    s_tlast          : in  std_logic_vector(INTERFACES - 1 downto 0);

    -- AXI master output
    m_tvalid         : out std_logic;
    m_tready         : in  std_logic;
    m_tdata          : out std_logic_vector(DATA_WIDTH - 1 downto 0);
    m_tlast          : out std_logic);
end axi_stream_arbiter;

architecture axi_stream_arbiter of axi_stream_arbiter is

  function keep_first_bit_set ( constant v : std_logic_vector ) return std_logic_vector is
    constant v_unsigned : unsigned(v'range) := unsigned(v);
  begin
    return std_logic_vector(v_unsigned and not (v_unsigned - 1));
  end;

  -------------
  -- Signals --
  -------------
  -- AXI slave input
  signal s_tvalid_i     : std_logic_vector(INTERFACES - 1 downto 0);
  signal s_tready_i     : std_logic_vector(INTERFACES - 1 downto 0);
  signal s_tdata_i      : std_logic_array_t(INTERFACES - 1 downto 0)(DATA_WIDTH - 1 downto 0);
  signal s_tlast_i      : std_logic_vector(INTERFACES - 1 downto 0);

  signal m_tvalid_i     : std_logic;
  signal m_tlast_i      : std_logic;
  signal s_tdata_packed : std_logic_array_t(INTERFACES - 1 downto 0)(DATA_WIDTH downto 0);
  signal m_tdata_packed : std_logic_vector(DATA_WIDTH downto 0);

  signal s_data_valid   : std_logic_vector(INTERFACES - 1 downto 0);
  signal m_data_valid   : std_logic;

  signal arbitrate      : std_logic;
  signal selected_i     : std_logic_vector(INTERFACES - 1 downto 0);
  signal selected_reg   : std_logic_vector(INTERFACES - 1 downto 0);

begin

  assert MODE = "ROUND_ROBIN" or MODE = "INTERLEAVED" or MODE = "ABSOLUTE"
    report "Invalid arbiter mode " & quote(MODE)
    severity Failure;

  -------------------
  -- Port mappings --
  -------------------
  g_route_inputs : for i in 0 to INTERFACES - 1 generate
    g_reg : if REGISTER_INPUTS generate
      signal tdata_in_agg   : std_logic_vector(DATA_WIDTH downto 0);
    begin
      reg_u : entity work.axi_stream_delay
          generic map (
              DELAY_CYCLES => 1,
              TDATA_WIDTH  => DATA_WIDTH + 1)
          port map (
              -- Usual ports
              clk     => clk,
              rst     => rst,

              -- AXI slave input
              s_tvalid => s_tvalid(i),
              s_tready => s_tready(i),
              s_tdata  => tdata_in_agg,

              -- AXI master output
              m_tvalid => s_tvalid_i(i),
              m_tready => s_tready_i(i),
              m_tdata  => s_tdata_packed(i));

      tdata_in_agg <= s_tlast(i) & s_tdata(i);
      s_tdata_i(i) <= s_tdata_packed(i)(DATA_WIDTH - 1 downto 0);
      s_tlast_i(i) <= s_tdata_packed(i)(DATA_WIDTH);
    end generate;

    g_no_reg : if not REGISTER_INPUTS generate
      s_tvalid_i(i)     <= s_tvalid(i);
      s_tready(i)       <= s_tready_i(i);
      s_tdata_i(i)      <= s_tdata(i);
      s_tlast_i(i)      <= s_tlast(i);
      s_tdata_packed(i) <= s_tlast(i) & s_tdata(i);
    end generate;
  end generate;

  axi_stream_mux_u : entity work.axi_stream_mux
    generic map (
      INTERFACES => INTERFACES,
      DATA_WIDTH => DATA_WIDTH + 1)
    port map (
      selection_mask => selected_i,

      s_tvalid      => s_tvalid_i,
      s_tready      => s_tready_i,
      s_tdata       => s_tdata_packed,

      m_tvalid      => m_tvalid_i,
      m_tready      => m_tready,
      m_tdata       => m_tdata_packed);

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  m_tdata      <= m_tdata_packed(DATA_WIDTH - 1 downto 0);
  m_tlast_i    <= m_tdata_packed(DATA_WIDTH);

  m_tvalid     <= m_tvalid_i;
  m_tlast      <= m_tlast_i;

  m_data_valid <= m_tvalid_i and m_tready;
  s_data_valid <= s_tvalid_i and s_tready_i;

  selected         <= selected_i;
  selected_encoded <= std_logic_vector(one_hot_to_decimal(selected_i));

  -- Common process
  process(clk, rst)
  begin
    if rst = '1' then
      arbitrate    <= '1';
      selected_reg <= (others => '0');
    elsif rising_edge(clk) then
      selected_reg <= selected_i;

      -- Arbitrate at the first word of every frame only
      if m_data_valid = '1' then
        arbitrate <= m_tlast_i;
      elsif or s_tvalid_i then
        arbitrate <= '0';
      end if;
    end if;
  end process;


  g_absolute : if MODE = "ABSOLUTE" generate
    selected_i <= selected_reg when not arbitrate    else
                  keep_first_bit_set(s_tvalid_i);
  end generate;


  g_interleaved : if MODE = "INTERLEAVED" generate
    signal selected_next : std_logic_vector(INTERFACES - 1 downto 0);
  begin
    selected_i <= selected_reg when not arbitrate    else
                  selected_next;

    process(clk, rst)
    begin
      if rst = '1' then
        selected_next    <= (others => '0');
        selected_next(0) <= '1';
      elsif rising_edge(clk) then
        if arbitrate and or s_tvalid_i then
          selected_next <= selected_next(INTERFACES - 2 downto 0) & selected_next(INTERFACES - 1);
        end if;
      end if;
    end process;
  end generate;

  g_round_robin : if MODE = "ROUND_ROBIN" generate
    signal waiting      : std_logic_vector(INTERFACES - 1 downto 0);
  begin
    selected_i <= selected_reg                 when not arbitrate                          else
                  keep_first_bit_set(waiting)  when or waiting                             else
                  -- Forward m_tready to all s_tready whenever there's no pending and no tvalid
                  (others => '1')              when s_tvalid_i = (s_tvalid_i'range => '0') else
                  keep_first_bit_set(s_tvalid_i);

    process(clk, rst)
    begin
      if rst = '1' then
        waiting      <= (others => '0');
      elsif rising_edge(clk) then
        if arbitrate = '1' then
          -- Serve interfaces that are waiting first and when that's complete serve from
          -- s_tvalid_i
          if or waiting then
            waiting <= waiting and not selected_i;
          else
            waiting <= s_tvalid_i and not selected_i;
          end if;
        end if;
      end if;
    end process;
  end generate g_round_robin;

end axi_stream_arbiter;
