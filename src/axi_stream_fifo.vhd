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
entity axi_stream_fifo is
  generic (
    FIFO_DEPTH : natural    := 1;
    DATA_WIDTH : natural    := 1;
    RAM_TYPE   : ram_type_t := auto);
  port (
    -- Usual ports
    clk     : in  std_logic;
    rst     : in  std_logic;

    -- status
    entries  : out std_logic_vector(numbits(FIFO_DEPTH) downto 0);
    empty    : out std_logic;
    full     : out std_logic;

    -- Write side
    s_tvalid : in  std_logic;
    s_tready : out std_logic;
    s_tdata  : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
    s_tlast  : in  std_logic;

    -- Read side
    m_tvalid : out std_logic;
    m_tready : in  std_logic;
    m_tdata  : out std_logic_vector(DATA_WIDTH - 1 downto 0);
    m_tlast  : out std_logic);
end axi_stream_fifo;

architecture axi_stream_fifo of axi_stream_fifo is

  -------------
  -- Signals --
  -------------
  signal s_axi_dv        : std_logic;

  signal ram_wr_ptr      : unsigned(numbits(FIFO_DEPTH) downto 0);
  signal ram_wr_data_agg : std_logic_vector(DATA_WIDTH downto 0);

  signal ram_rd_en       : std_logic;
  signal ram_rd_en_reg   : std_logic;
  signal ram_rd_ptr      : unsigned(numbits(FIFO_DEPTH) downto 0);
  signal ram_rd_data_agg : std_logic_vector(DATA_WIDTH downto 0);

  signal ptr_diff        : unsigned(numbits(FIFO_DEPTH) downto 0);

  -- AXI stream master adapter interface
  signal ram_rd_full     : std_logic;
  signal ram_rd_empty    : std_logic;
  signal ram_rd_dv       : std_logic;
  signal ram_rd_tdata    : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal ram_rd_tlast    : std_logic;

  -- Internals
  signal m_tvalid_i      : std_logic;
  signal s_tready_i      : std_logic;
  signal ram_wr_addr     : std_logic_vector(numbits(FIFO_DEPTH) - 1 downto 0);
  signal ram_rd_addr     : std_logic_vector(numbits(FIFO_DEPTH) - 1 downto 0);


begin

  -------------------
  -- Port mappings --
  -------------------
  ram_u : entity work.ram_inference
    generic map (
      DEPTH        => FIFO_DEPTH,
      DATA_WIDTH   => DATA_WIDTH + 1,
      RAM_TYPE     => RAM_TYPE,
      OUTPUT_DELAY => 1)
    port map (
      -- Port A
      clk_a     => clk,
      clken_a   => '1',
      wren_a    => s_axi_dv,
      addr_a    => ram_wr_addr,
      wrdata_a  => ram_wr_data_agg,
      rddata_a  => open,

      -- Port B
      clk_b     => clk,
      clken_b   => '1',
      addr_b    => ram_rd_addr,
      rddata_b  => ram_rd_data_agg);

  output_adapter_u : entity work.axi_stream_master_adapter
    generic map (
      MAX_SKEW_CYCLES => 2,
      TDATA_WIDTH     => DATA_WIDTH)
    port map (
      -- Usual ports
      clk      => clk,
      reset    => rst,
      -- wanna-be AXI interface
      wr_en    => ram_rd_dv,
      wr_full  => ram_rd_full,
      wr_empty => ram_rd_empty,
      wr_data  => ram_rd_tdata,
      wr_last  => ram_rd_tlast,
      -- AXI master
      m_tvalid => m_tvalid_i,
      m_tready => m_tready,
      m_tdata  => m_tdata ,
      m_tlast  => m_tlast);

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  ram_wr_data_agg <= s_tlast & s_tdata;

  s_tready_i  <= not full;
  s_axi_dv    <= s_tready_i and s_tvalid;

  -- Read when ram is not full and pointer diff is not 0
  ram_rd_en   <= not ram_rd_full and or(ptr_diff);

  -- Assign internals
  s_tready    <= s_tready_i;
  m_tvalid    <= m_tvalid_i;
  -- GHDL fails with bound check error if this is wired directly
  ram_wr_addr <= std_logic_vector(ram_wr_ptr(ram_wr_ptr'length - 2 downto 0));
  ram_rd_addr <= std_logic_vector(ram_rd_ptr(ram_rd_ptr'length - 2 downto 0));

  entries     <= std_logic_vector(ptr_diff);
  -- FIFO is empty when the output adapter is empty and ptr diff is 0
  empty       <= ram_rd_empty and and(not ptr_diff);
  -- Full when ptr_diff equals FIFO depth, i.e., delta is all 0s
  full        <= and(not(ptr_diff - FIFO_DEPTH + 1));

  ---------------
  -- Processes --
  ---------------
  wr_side_p : process(clk)
  begin
    if rising_edge(clk) then
      ram_rd_dv     <= '0';
      ram_rd_en_reg <= ram_rd_en;

      -- Handle write pointer increment (FIFO_DEPTH is not necessarily a power of 2)
      if s_axi_dv = '1' then
        if ram_wr_ptr = FIFO_DEPTH - 1 then
          ram_wr_ptr <= (others => '0');
        else
          ram_wr_ptr <= ram_wr_ptr + 1;
        end if;
      end if;

      -- Handle read pointer increment (FIFO_DEPTH is not necessarily a power of 2)
      if ram_rd_en = '1' then
        if ram_rd_ptr = FIFO_DEPTH - 1 then
          ram_rd_ptr <= (others => '0');
        else
          ram_rd_ptr <= ram_rd_ptr + 1;
        end if;
      end if;

      -- Data takes 1 cycle to come out after we've updated the pointer, catch it when it
      -- does
      if ram_rd_en_reg = '1' then
        ram_rd_dv   <= '1';
        ram_rd_tdata <= ram_rd_data_agg(DATA_WIDTH - 1 downto 0);
        ram_rd_tlast <= ram_rd_data_agg(DATA_WIDTH);
      end if;

      -- Calculate the pointer difference without using the actual pointers; FIFO_DEPTH is
      -- not necessarily a power of 2
      if s_axi_dv = '1' and ram_rd_en = '0' then
        ptr_diff <= ptr_diff + 1;
      elsif s_axi_dv = '0' and ram_rd_en = '1' then
        ptr_diff <= ptr_diff - 1;
      end if;

      if rst = '1' then
        ptr_diff      <= (others => '0');
        ram_wr_ptr    <= (others => '0');
        ram_rd_ptr    <= (others => '0');
        ram_rd_dv     <= '0';
        ram_rd_en_reg <= '0';
      end if;
    end if;
  end process;

end axi_stream_fifo;
