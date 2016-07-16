--
-- hdl_lib -- An HDL core library
--
-- Copyright 2014-2016 by Andre Souto (suoto)
--
-- This file is part of hdl_lib.
-- 
-- hdl_lib is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
-- 
-- hdl_lib is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with hdl_lib.  If not, see <http://www.gnu.org/licenses/>.

---------------------------------
-- Block name and description --
--------------------------------

---------------
-- Libraries --
---------------
library	ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library common_lib;
    use common_lib.common_pkg.all;

library memory;

------------------------
-- Entity declaration --
------------------------
entity async_fifo is
    generic (
        -- FIFO configuration
        FIFO_LEN         : positive := 512;         -- FIFO length in number of positions
        UPPER_TRESHOLD   : natural  := 510;         -- FIFO level to assert wr_upper
        LOWER_TRESHOLD   : natural  := 10;          -- FIFO level to assert rd_lower
        DATA_WIDTH       : natural  := 8;           -- Data width
        -- FIFO config for error cases
        OVERFLOW_ACTION  : string   := "SATURATE";
        UNDERFLOW_ACTION : string   := "SATURATE");
    port (
        -- Write port
        wr_clk      : in  std_logic;        -- Write clock
        wr_clken    : in  std_logic := '1'; -- Write clock enable
        wr_arst     : in  std_logic;        -- Write side asynchronous reset
        wr_data     : in  std_logic_vector(DATA_WIDTH - 1 downto 0); -- Fifo write data
        wr_en       : in  std_logic;        -- Fifo write enable
        wr_full     : out std_logic;        -- Fifo write full status
        wr_upper    : out std_logic;        -- Fifo write upper status

        -- Read port
        rd_clk      : in  std_logic;        -- Read clock
        rd_clken    : in  std_logic := '1'; -- Read clock enable
        rd_arst     : in  std_logic;        -- Read side asynchronous reset
        rd_data     : out std_logic_vector(DATA_WIDTH - 1 downto 0); -- Fifo read data
        rd_en       : in  std_logic;        -- Read enable
        rd_dv       : out std_logic;        -- Read data valid
        rd_lower    : out std_logic;        -- Fifo lower threshold
        rd_empty    : out std_logic);       -- Fifo empty status
end async_fifo;

architecture async_fifo of async_fifo is

    -------------
    -- Signals --
    -------------
    -- Signals on the write side of the FIFO
    signal wr_ptr      : unsigned(numbits(FIFO_LEN) - 1 downto 0) := (others => '0');
    signal wclk_rd_ptr : unsigned(numbits(FIFO_LEN) - 1 downto 0) := (others => '0');
    signal wclk_pdiff  : unsigned(numbits(FIFO_LEN) - 1 downto 0);

    -- Signals on the write side of the FIFO
    signal rd_ptr      : unsigned(numbits(FIFO_LEN) - 1 downto 0) := (others => '0');
    signal rclk_wr_ptr : unsigned(numbits(FIFO_LEN) - 1 downto 0) := (others => '0');
    signal rclk_pdiff  : unsigned(numbits(FIFO_LEN) - 1 downto 0);

    -- Signals used to cross clock domains
    signal wr_ptr_gray : unsigned(numbits(FIFO_LEN) - 1 downto 0);
    signal rd_ptr_gray : unsigned(numbits(FIFO_LEN) - 1 downto 0);

    signal fifo_full_wr  : std_logic;
    signal fifo_empty_rd : std_logic;

    signal error_wr      : std_logic;
    signal error_rd_wr   : std_logic;
    signal error_rd      : std_logic;
    signal error_wr_rd   : std_logic;

begin

    -------------------
    -- Port mappings --
    -------------------
    mem : entity memory.ram_inference
        generic map (
            ADDR_WIDTH         => numbits(FIFO_LEN),
            DATA_WIDTH         => DATA_WIDTH,
            EXTRA_OUTPUT_DELAY => 0)
        port map (
            -- Port A
            clk_a     => wr_clk,
            clken_a   => wr_clken,
            wren_a    => wr_en,
            addr_a    => std_logic_vector(wr_ptr),
            wrdata_a  => wr_data,
            rddata_a  => open,

            -- Port B
            clk_b     => rd_clk,
            clken_b   => rd_clken,
            addr_b    => std_logic_vector(rd_ptr),
            rddata_b  => rd_data);

    wr_error_s : entity common_lib.pulse_sync
        generic map (
            EXTRA_DELAY_CYCLES => 0)
        port map (
            -- Usual ports
            src_clk     => wr_clk,
            src_clken   => wr_clken,
            src_pulse   => error_wr,

            dst_clk     => rd_clk,
            dst_clken   => rd_clken,
            dst_pulse   => error_wr_rd);

    rd_error_s : entity common_lib.pulse_sync
        generic map (
            EXTRA_DELAY_CYCLES => 0)
        port map (
            -- Usual ports
            src_clk     => rd_clk,
            src_clken   => rd_clken,
            src_pulse   => error_rd,

            dst_clk     => wr_clk,
            dst_clken   => wr_clken,
            dst_pulse   => error_rd_wr);

    ------------------------------
    -- Asynchronous assignments --
    ------------------------------
    wclk_pdiff      <= wr_ptr - wclk_rd_ptr;
    rclk_pdiff      <= rclk_wr_ptr - rd_ptr;

    fifo_full_wr    <= '1' when wclk_pdiff = FIFO_LEN - 1 else '0';
    fifo_empty_rd   <= '1' when rclk_pdiff = 0 else '0';

    wr_full         <= fifo_full_wr;
    rd_empty        <= fifo_empty_rd;


    ---------------
    -- Processes --
    ---------------
    process(wr_clk, wr_arst)
    begin
        if wr_arst = '1' then
            wr_ptr      <= (others => '0');
            wclk_rd_ptr <= (others => '0');
            wr_ptr_gray <= (others => '0');
        elsif wr_clk'event and wr_clk = '1' then
            if wr_clken = '1' then
                
                -- Get the binary value of the read pointer inside the write clock
                wclk_rd_ptr <= gray_to_bin(rd_ptr_gray);
                wr_ptr_gray <= bin_to_gray(wr_ptr);

                wr_upper <= '0';
                if wclk_pdiff >= UPPER_TRESHOLD then
                    wr_upper <= '1';
                end if;

                error_wr <= '0';
                if wr_en = '1' then
                    if OVERFLOW_ACTION = "SATURATE" and fifo_full_wr = '0' then
                        wr_ptr <= wr_ptr + 1;
                    elsif OVERFLOW_ACTION = "RESET" then
                        if fifo_full_wr = '0' then
                            wr_ptr <= wr_ptr + 1;
                        else
                            error_wr <= '1';
                            wr_ptr   <= (others => '0');
                        end if;
                    end if;
                end if;

                if error_rd_wr = '1' then
                    wr_ptr <= (others => '0');
                end if;
            end if;
        end if;
    end process;

    process(rd_clk, rd_arst)
    begin
        if rd_arst = '1' then
            rd_ptr      <= (others => '0');
            rclk_wr_ptr <= (others => '0');
            rd_ptr_gray <= (others => '0');
        elsif rd_clk'event and rd_clk = '1' then
            if rd_clken = '1' then
                -- Get the binary value of the write pointer inside the read clock
                rclk_wr_ptr <= gray_to_bin(wr_ptr_gray);
                rd_ptr_gray <= bin_to_gray(rd_ptr);
                
                rd_lower <= '0';
                if rclk_pdiff <= LOWER_TRESHOLD then
                    rd_lower <= '1';
                end if;

                rd_dv    <= '0';
                error_rd <= '0';
                if rd_en = '1' then
                    if UNDERFLOW_ACTION = "SATURATE" and fifo_empty_rd = '0' then
                        rd_dv  <= '1';
                        rd_ptr <= rd_ptr + 1;
                    elsif UNDERFLOW_ACTION = "RESET" then
                        if fifo_empty_rd = '0' then
                            rd_dv  <= '1';
                            rd_ptr <= rd_ptr + 1;
                        else
                            error_rd <= '1';
                            rd_ptr   <= (others => '0');
                        end if;
                    end if;
                end if;
                if error_wr_rd = '1' then
                    rd_ptr <= (others => '0');
                end if;
            end if;
        end if;
    end process;
end async_fifo;

