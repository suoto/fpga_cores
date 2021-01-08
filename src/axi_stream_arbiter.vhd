--
-- FPGA Cores -- An HDL core library
--
-- Copyright 2014-2016 by Andre Souto (suoto)
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
    MODE       : string   := "ROUND_ROBIN"; -- ROUND_ROBIN, INTERLEAVED, ABSOLUTE
    INTERFACES : positive := 1;
    DATA_WIDTH : positive := 1);
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
  signal s_tready_i     : std_logic_vector(INTERFACES - 1 downto 0);
  signal m_tvalid_i     : std_logic;
  signal m_tlast_i      : std_logic;
  signal s_tdata_packed : std_logic_array_t(INTERFACES - 1 downto 0)(DATA_WIDTH downto 0);
  signal m_tdata_packed : std_logic_vector(DATA_WIDTH downto 0);

  signal s_data_valid   : std_logic_vector(INTERFACES - 1 downto 0);
  signal m_data_valid   : std_logic;

  signal selected_i     : std_logic_vector(INTERFACES - 1 downto 0);

begin

  assert MODE = "ROUND_ROBIN" or MODE = "INTERLEAVED" or MODE = "ABSOLUTE"
    report "Invalid arbiter mode " & quote(MODE)
    severity Failure;

  -------------------
  -- Port mappings --
  -------------------

  g_s_tdata_packed : for i in 0 to INTERFACES - 1 generate
    s_tdata_packed(i) <= s_tlast(i) & s_tdata(i);
  end generate g_s_tdata_packed;

  axi_stream_mux_u : entity work.axi_stream_mux
    generic map (
      INTERFACES => INTERFACES,
      DATA_WIDTH => DATA_WIDTH + 1)
    port map (
     selection_mask => selected_i,

      s_tvalid      => s_tvalid,
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
  s_tready     <= s_tready_i;
  m_tlast      <= m_tlast_i;

  m_data_valid <= m_tvalid_i and m_tready;
  s_data_valid <= s_tvalid and s_tready_i;

  selected         <= selected_i;
  selected_encoded <= std_logic_vector(one_hot_to_decimal(selected_i));

  g_round_robin : if MODE = "ROUND_ROBIN" generate
    signal waiting      : std_logic_vector(INTERFACES - 1 downto 0);
    signal arbitrate    : std_logic;
    signal selected_reg : std_logic_vector(INTERFACES - 1 downto 0);
  begin
    selected_i <= selected_reg                 when not arbitrate    else
                  keep_first_bit_set(waiting)  when or waiting       else
                  keep_first_bit_set(s_tvalid);

    process(clk, rst)
    begin
      if rst = '1' then
        selected_reg <= (others => '0');
        waiting      <= (others => '0');
        arbitrate    <= '1';
      elsif rising_edge(clk) then
        selected_reg <= selected_i;

        -- Arbitrate at the first word of every frame only
        if m_data_valid = '1' then
          arbitrate <= m_tlast_i;
        elsif or s_tvalid then
          arbitrate <= '0';
        end if;

        if arbitrate = '1' then
          -- Serve interfaces that are waiting first and when that's complete
          -- serve from s_tvalid
          if or waiting then
            waiting <= waiting and not selected_i;
          else
            waiting <= s_tvalid and not selected_i;
          end if;
        end if;

      end if;
    end process;
  end generate g_round_robin;

end axi_stream_arbiter;