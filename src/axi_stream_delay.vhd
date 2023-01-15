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
entity axi_stream_delay is
    generic (
        DELAY_CYCLES : natural := 0;
        TDATA_WIDTH  : integer := 8);
    port (
        -- Usual ports
        clk     : in  std_logic;
        rst     : in  std_logic;

        -- AXI slave input
        s_tvalid : in std_logic;
        s_tready : out std_logic;
        s_tdata  : in std_logic_vector(TDATA_WIDTH - 1 downto 0);

        -- AXI master output
        m_tvalid : out std_logic;
        m_tready : in std_logic;
        m_tdata  : out std_logic_vector(TDATA_WIDTH - 1 downto 0));
end axi_stream_delay;

architecture axi_stream_delay of axi_stream_delay is

    -----------
    -- Types --
    -----------
    type tdata_t is array (natural range <>) of std_logic_vector(TDATA_WIDTH - 1 downto 0);

    -------------
    -- Signals --
    -------------
    signal tdata_pipe  : tdata_t(DELAY_CYCLES downto 0);
    signal tvalid_pipe : std_logic_vector(DELAY_CYCLES downto 0);
    signal tready_pipe : std_logic_vector(DELAY_CYCLES downto 0);

begin

    -------------------
    -- Port mappings --
    -------------------
    g_skid_buffers : for i in 0 to DELAY_CYCLES - 1 generate
        dut : entity work.skidbuffer
            generic map (
                OPT_LOWPOWER    => False,
                OPT_OUTREG      => True,
                OPT_PASSTHROUGH => False,
                DW              => TDATA_WIDTH)
            port map (
                i_clk    => clk,
                i_reset  => rst,

                i_valid  => tvalid_pipe(i),
                o_ready  => tready_pipe(i),
                i_data   => tdata_pipe(i),

                o_valid => tvalid_pipe(i + 1),
                i_ready => tready_pipe(i + 1),
                o_data  => tdata_pipe(i + 1));
    end generate g_skid_buffers;

    ------------------------------
    -- Asynchronous assignments --
    ------------------------------
    tvalid_pipe(0) <= s_tvalid;
    tdata_pipe(0)  <= s_tdata;
    s_tready       <= tready_pipe(0);

    m_tvalid                  <= tvalid_pipe(DELAY_CYCLES);
    m_tdata                   <= tdata_pipe(DELAY_CYCLES);
    tready_pipe(DELAY_CYCLES) <= m_tready;

end axi_stream_delay;
