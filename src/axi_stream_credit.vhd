--
-- FPGA core library
--
-- Copyright 2022 by Andre Souto (suoto)
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
entity axi_stream_credit is
  generic (
    CREDITS     : natural := 8;
    TDATA_WIDTH : natural := 16);
  port (
    clk              : in  std_logic;
    rst              : in  std_logic;

    credit_return_en : in  std_logic;
    credit_return    : in  std_logic_vector(numbits(CREDITS + 1) - 1 downto 0);
    credits_available: out std_logic_vector(numbits(CREDITS + 1) - 1 downto 0);

    -- AXI slave input
    s_tvalid         : in  std_logic;
    s_tready         : out std_logic;
    s_tdata          : in  std_logic_vector(TDATA_WIDTH - 1 downto 0);

    -- AXI master output
    m_tvalid         : out std_logic;
    m_tready         : in  std_logic;
    m_tdata          : out std_logic_vector(TDATA_WIDTH - 1 downto 0));
end axi_stream_credit;

architecture axi_stream_credit of axi_stream_credit is

  constant CREDITS_WIDTH : integer := numbits(CREDITS + 1);

  -------------
  -- Signals --
  -------------
  signal s_tready_i             : std_logic;
  signal enable                 : std_logic;
  signal s_data_valid           : std_logic;
  signal credits_available_ff   : unsigned(CREDITS_WIDTH - 1 downto 0);
  signal credits_available_next : unsigned(CREDITS_WIDTH - 1 downto 0);

begin

  -------------------
  -- Port mappings --
  -------------------
  flow_control_u : entity work.axi_stream_flow_control
    generic map ( DATA_WIDTH => TDATA_WIDTH )
    port map (
      -- Usual ports
      enable   => enable,

      s_tvalid => s_tvalid,
      s_tready => s_tready_i,
      s_tdata  => s_tdata,

      m_tvalid => m_tvalid,
      m_tready => m_tready,
      m_tdata  => m_tdata);

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  s_data_valid      <= s_tvalid and s_tready_i;

  enable            <= '1' when or(credits_available_ff) else
                       '1' when credit_return_en = '1' and unsigned(credit_return) > 0 else
                       '0';

  s_tready          <= s_tready_i;
  credits_available <= std_logic_vector(credits_available_ff(numbits(CREDITS + 1) - 1 downto 0));

  ---------------
  -- Processes --
  ---------------
  process(clk, rst)
  begin
    if rst = '1' then
      credits_available_ff <= to_unsigned(CREDITS, credits_available_ff'length);
    elsif rising_edge(clk) then
      credits_available_ff <= credits_available_next;
    end if;
  end process;

  credits_available_next
    <= credits_available_ff - 1                           when     s_data_valid and not credit_return_en else
       credits_available_ff + unsigned(credit_return)     when not s_data_valid and     credit_return_en else
       credits_available_ff + unsigned(credit_return) - 1 when     s_data_valid and     credit_return_en else
       credits_available_ff;

end axi_stream_credit;
