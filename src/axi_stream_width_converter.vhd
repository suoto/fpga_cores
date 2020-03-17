--
-- DVB IP
--
-- Copyright 2019 by Suoto <andre820@gmail.com>
--
-- This file is part of DVB IP.
--
-- DVB IP is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- DVB IP is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with DVB IP.  If not, see <http://www.gnu.org/licenses/>.

---------------
-- Libraries --
---------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

------------------------
-- Entity declaration --
------------------------
entity axi_stream_width_converter is
  generic (
    INPUT_DATA_WIDTH  : natural := 24;
    OUTPUT_DATA_WIDTH : natural := 16;
    AXI_TID_WIDTH     : natural := 8);
  port (
    -- Usual ports
    clk      : in  std_logic;
    rst      : in  std_logic;
    -- AXI stream input
    s_tready : out std_logic;
    s_tdata  : in  std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);
    s_tkeep  : in  std_logic_vector((INPUT_DATA_WIDTH + 7) / 8 - 1 downto 0);
    s_tid    : in  std_logic_vector(AXI_TID_WIDTH - 1 downto 0);
    s_tvalid : in  std_logic;
    s_tlast  : in  std_logic;
    -- AXI stream output
    m_tready : in  std_logic;
    m_tdata  : out std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);
    m_tkeep  : out std_logic_vector((OUTPUT_DATA_WIDTH + 7) / 8 - 1 downto 0) := (others => '0');
    m_tid    : out std_logic_vector(AXI_TID_WIDTH - 1 downto 0) := (others => '0');
    m_tvalid : out std_logic;
    m_tlast  : out std_logic := '0');
end axi_stream_width_converter;

architecture axi_stream_width_converter of axi_stream_width_converter is

  ---------------
  -- Constants --
  ---------------
  constant INPUT_BYTE_WIDTH  : natural := (INPUT_DATA_WIDTH + 7) / 8;
  constant OUTPUT_BYTE_WIDTH : natural := (OUTPUT_DATA_WIDTH + 7) / 8;

  ------------------
  -- Sub programs --
  ------------------
  -- When s_tlast is high, tkeep will flag how many bytes are actually valid
  function count_ones ( constant v : std_logic_vector ) return natural is
    variable cnt : natural := 0;
  begin
    for i in v'range loop
      if v(i) = '1' then
        cnt := cnt + 1;
      end if;
    end loop;

    return cnt;
  end;

  -- Sets the appropriate tkeep bits so that it representes the specified number of bytes,
  -- where bytes are in the LSB of tdata
  function get_tkeep ( constant valid_bytes : natural; constant width : natural ) return std_logic_vector is
    variable result : std_logic_vector(width - 1 downto 0) := (others => '0');
  begin
    for i in 0 to result'length - 1 loop
      if i < valid_bytes then
        result(i) := '1';
      else
        result(i) := '0';
      end if;
    end loop;
    return result;
  end;

  -----------
  -- Types --
  -----------

  -------------
  -- Signals --
  -------------
  signal s_first_word : std_logic;
  signal s_data_valid : std_logic;
  signal m_data_valid : std_logic;
  signal s_tready_i   : std_logic;
  signal m_tvalid_i   : std_logic;
  signal m_tlast_i    : std_logic;

begin

  g_pass_through : if INPUT_DATA_WIDTH = OUTPUT_DATA_WIDTH generate -- {{
    signal s_tid_reg  : std_logic_vector(AXI_TID_WIDTH - 1 downto 0);
  begin

    s_tready_i <= m_tready;
    m_tdata    <= s_tdata;
    m_tkeep    <= s_tkeep;
    m_tvalid_i <= s_tvalid;
    m_tlast_i  <= s_tlast;
    m_tid      <= s_tid when s_first_word else s_tid_reg;

    process(clk)
    begin
      if rising_edge(clk) then
        if s_data_valid = '1' and s_first_word = '1' then
          s_tid_reg <= s_tid;
        end if;
      end if;
    end process;

  end generate g_pass_through; -- }}

  g_downsize : if INPUT_DATA_WIDTH > OUTPUT_DATA_WIDTH generate -- {{
    signal dbg_tmp       : std_logic_vector(2*(INPUT_DATA_WIDTH + OUTPUT_DATA_WIDTH) - 1 downto 0);
    signal dbg_bit_cnt   : natural range 0 to dbg_tmp'length - 1;
    signal dbg_flush_req : boolean := False;
  begin
    -------------------
    -- Port mappings --
    -------------------
    -- Need a small FIFO for the TID
    tid_fifo_u : entity work.sync_fifo
      generic map (
        -- FIFO configuration
        RAM_INFERENCE_STYLE => "distributed", -- : string   := "auto";
        DEPTH               => 4, -- : positive := 512; -- FIFO length in number of positions
        DATA_WIDTH          => AXI_TID_WIDTH, -- : natural  := 8;  -- Data width
        UPPER_TRESHOLD      => 3, -- : natural  := 510; -- FIFO level to assert upper
        LOWER_TRESHOLD      => 1) -- : natural  := 10);  -- FIFO level to assert lower
      port map (
        -- Write port
        clk     => clk,
        clken   => '1',
        rst     => rst,

        -- Status
        full    => open, --full ,
        upper   => open, --upper,
        lower   => open, --lower,
        empty   => open, --empty,

        wr_en   => s_first_word and s_data_valid,
        wr_data => s_tid,

        -- Read port
        rd_en   => m_tlast_i and m_tvalid_i and m_tready, --'0',
        rd_data => m_tid,
        rd_dv   => open);


    ---------------
    -- Processes --
    ---------------
    process(clk)
      variable tmp       : std_logic_vector(2*(INPUT_DATA_WIDTH + OUTPUT_DATA_WIDTH) - 1 downto 0);
      variable bit_cnt   : natural range 0 to tmp'length - 1;
      variable flush_req : boolean := False;

    begin
      if rising_edge(clk) then

        -- De-assert tvalid when data in being sent and no more data, except when we're
        -- flushing the output buffer
        if m_tready = '1' and (bit_cnt >= OUTPUT_DATA_WIDTH or flush_req) then
          if m_tlast_i = '1' then
            flush_req := False;
          end if;
          m_tvalid_i <= '0';
          m_tlast_i  <= '0';
        end if;

        -- Handling incoming data
        if s_data_valid = '1' then
          s_tready_i <= '0'; -- Each incoming word will generate at least 1 output word

          -- Need to assign data before bit_cnt (it's a variable)
          tmp(INPUT_DATA_WIDTH + bit_cnt - 1 downto bit_cnt) := s_tdata;
          if s_tlast = '0' then
            bit_cnt := bit_cnt + INPUT_DATA_WIDTH;
          else
            -- Last word, add the appropriate number of bits
            bit_cnt := bit_cnt + 8*count_ones(s_tkeep);
          end if;

          -- Upon receiving the last input word, clear the flush request
          if s_tlast = '1' then
            flush_req := True;
          end if;

        end if;

        if m_data_valid = '1' then
          -- Consume the data we wrote
          tmp     := (OUTPUT_DATA_WIDTH - 1 downto 0 => 'U') & tmp(tmp'length - 1 downto OUTPUT_DATA_WIDTH);
          m_tkeep <= (others => '0');

          -- Clear up for the next frame
          if m_tlast_i = '1' then
            bit_cnt   := 0;
            flush_req := False;
          else
            bit_cnt := bit_cnt - OUTPUT_DATA_WIDTH;
          end if;

        end if;

        if bit_cnt >= OUTPUT_DATA_WIDTH or flush_req then
          m_tvalid_i <= '1';
          m_tdata    <= tmp(OUTPUT_DATA_WIDTH - 1 downto 0);
          m_tkeep    <= (others => '0');

          -- Work out if the next word will be the last and fill in the bit mask
          -- appropriately
          if bit_cnt <= OUTPUT_DATA_WIDTH and flush_req then
            m_tlast_i <= '1';
            if OUTPUT_DATA_WIDTH < 8 then
              m_tkeep <= (others => '1');
            else
              m_tkeep <= get_tkeep((bit_cnt + 7) / 8, OUTPUT_BYTE_WIDTH);
            end if;
          end if;
        end if;

        -- Input should always be ready if there's room for data to be received, unless
        -- we're flushing the buffer. In this case, accepting more data will mess up with
        -- the tracking of how much data we still have to write
        if (tmp'length - bit_cnt > INPUT_DATA_WIDTH) and not flush_req then
          s_tready_i <= '1';
        end if;

        dbg_tmp       <= tmp;
        dbg_bit_cnt   <= bit_cnt;
        dbg_flush_req <= flush_req;

        if rst = '1' then
          s_tready_i <= '1';
          m_tvalid_i <= '0';
          m_tlast_i  <= '0';
        end if;
      end if;
    end process;
  end generate g_downsize; -- }}

  -------------------
  -- Port mappings --
  -------------------

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  s_data_valid     <= s_tready_i and s_tvalid and not rst;
  m_data_valid     <= m_tready and m_tvalid_i and not rst;

  s_tready <= s_tready_i;
  m_tvalid <= m_tvalid_i;
  m_tlast  <= m_tlast_i;

  ---------------
  -- Processes --
  ---------------
  -- First word flagging is common
  process(clk, rst)
  begin
    if rst = '1' then
      s_first_word <= '1';
    elsif rising_edge(clk) then

      if s_data_valid = '1' then
        s_first_word <= s_tlast;
      end if;

    end if;
  end process;

end axi_stream_width_converter;

-- vim: set foldmethod=marker foldmarker=--\ {{,--\ }} :
