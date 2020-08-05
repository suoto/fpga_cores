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

-- FPGA Cores is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with FPGA Cores.  If not, see <http://www.gnu.org/licenses/>.

-- #####################################################################################
-- ## Libraries ########################################################################
-- #####################################################################################
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common_pkg.all;

-- #####################################################################################
-- ## Entity declaration ###############################################################
-- #####################################################################################
entity sync_fifo is
  generic (
    -- FIFO configuration
    RAM_TYPE           : ram_type_t := auto;
    DEPTH              : natural := 512;    -- FIFO length in number of positions
    DATA_WIDTH         : natural := 8;      -- Data width
    UPPER_TRESHOLD     : natural := 510;    -- FIFO level to assert upper
    LOWER_TRESHOLD     : natural := 10;     -- FIFO level to assert lower
    EXTRA_OUTPUT_DELAY : natural := 0);     --
  port (
    -- Write port
    clk     : in  std_logic;        -- Write clock
    clken   : in  std_logic := '1'; -- Write clock enable
    rst     : in  std_logic;        -- Write side asynchronous reset

    -- Status
    full    : out std_logic;        -- Fifo write full status
    upper   : out std_logic;        -- Fifo write upper status
    lower   : out std_logic;        -- Fifo lower threshold
    empty   : out std_logic;        -- Fifo empty status

    wr_en   : in  std_logic;        -- Fifo write enable
    wr_data : in  std_logic_vector(DATA_WIDTH - 1 downto 0); -- Fifo write data

    -- Read port
    rd_en   : in  std_logic;        -- Read enable
    rd_data : out std_logic_vector(DATA_WIDTH - 1 downto 0); -- Fifo read data
    rd_dv   : out std_logic);        -- Read data valid
end sync_fifo;

architecture sync_fifo of sync_fifo is

  -------------
  -- Signals --
  -------------
  signal wr_ptr      : unsigned(numbits(DEPTH) - 1 downto 0)  := (others => '0');
  signal rd_ptr      : unsigned(numbits(DEPTH) - 1 downto 0)  := (others => '0');
  signal ptr_diff    : unsigned(numbits(DEPTH) - 1 downto 0);

  signal rd_dv_async : std_logic; -- Read data valid (async)
  signal rd_dv_reg   : std_logic; -- Read data valid (registered)

  signal inc_wr_ptr  : std_logic;
  signal inc_rd_ptr  : std_logic;

  signal full_i      : std_logic;
  signal empty_i     : std_logic;

begin

  -------------------
  -- Port mappings --
  -------------------
  mem : entity work.ram_inference
    generic map (
      ADDR_WIDTH   => numbits(DEPTH),
      DATA_WIDTH   => DATA_WIDTH,
      RAM_TYPE     => RAM_TYPE,
      OUTPUT_DELAY => EXTRA_OUTPUT_DELAY)
    port map (
      -- Port A
      clk_a    => clk,
      clken_a  => clken,
      wren_a   => wr_en,
      addr_a   => std_logic_vector(wr_ptr),
      wrdata_a => wr_data,
      rddata_a => open,

      -- Port B
      clk_b    => clk,
      clken_b  => clken,
      addr_b   => std_logic_vector(rd_ptr),
      rddata_b => rd_data);

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  full_i     <= '1' when ptr_diff = DEPTH - 1 else '0';
  empty_i    <= '1' when ptr_diff = 0 else '0';

  inc_wr_ptr <= wr_en when clken = '1' and full_i = '0' else '0';
  inc_rd_ptr <= rd_en when clken = '1' and empty_i = '0' else '0';

  rd_dv_async <= inc_rd_ptr;

  -- Set thesholds
  upper      <= '1' when ptr_diff >= UPPER_TRESHOLD else '0';
  lower      <= '1' when ptr_diff <= LOWER_TRESHOLD else '0';

  -- Assign internals
  full       <= full_i;
  empty      <= empty_i;

  g_rd_dv_async : if EXTRA_OUTPUT_DELAY = 0 generate
    rd_dv <= rd_dv_async;
  end generate;

  g_rd_dv_reg : if EXTRA_OUTPUT_DELAY /= 0 generate
    rd_dv <= rd_dv_reg;
  end generate;

  ---------------
  -- Processes --
  ---------------
  process(clk, rst)
  begin
    if rst = '1' then
      wr_ptr    <= (others => '0');
      rd_ptr    <= (others => '0');
      ptr_diff  <= (others => '0');
      rd_dv_reg <= '0';
    elsif clk'event and clk = '1' then
      if clken = '1' then

        rd_dv_reg <= '0';

        if inc_wr_ptr = '1' and inc_rd_ptr = '0' then
          ptr_diff <= ptr_diff + 1;
        elsif inc_wr_ptr = '0' and inc_rd_ptr = '1' then
          ptr_diff <= ptr_diff - 1;
        end if;

        if inc_wr_ptr = '1' then
          wr_ptr <= wr_ptr + 1;
        end if;

        if inc_rd_ptr = '1' then
          rd_dv_reg <= '1';
          rd_ptr    <= rd_ptr + 1;
        end if;

      end if;
    end if;
  end process;

  overflow_report_p : process(clk)
    variable notified : boolean := False;
  begin
    if rising_edge(clk) then
      if clken = '1' and rst = '0' then
        if full_i = '1' and wr_en = '1' then
          if not notified then
            report "FIFO overflow"
            severity Warning;
          end if;
          notified := True;
        else
          notified := False;
        end if;
      end if;
    end if;
  end process;

  -- synthesis translate_off
  g_check : if IS_SIMULATION generate
      signal rst_prev : std_logic;
  begin
    check_rst_p : process(clk)
    begin
      if rising_edge(clk) then

        rst_prev <= rst;

        if rst_prev = '0' and rst = '1' then
          assert to_01(empty_i) = '1'
            report "Empty should be '1' upon reset, but it's '" & to_string(empty_i) & "'"
            severity Error;

          assert to_01(full_i) = '0'
            report "Full should be '0' upon reset, but it's '" & to_string(full_i) & "'"
            severity Error;
        end if;

      end if;
    end process;
  end generate;
  -- synthesis translate_on

end sync_fifo;
