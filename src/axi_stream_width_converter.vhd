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

---------------------------------
-- Block name and description --
--------------------------------

---------------
-- Libraries --
---------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

library str_format;
use str_format.str_format_pkg.all;

------------------------
-- Entity declaration --
------------------------
entity axi_stream_width_converter is
  generic (
    INPUT_DATA_WIDTH  : natural := 16;
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

  ------------------
  -- Sub programs --
  ------------------
  function get_tkeep_bytes_table ( constant width : natural ) return work.common_pkg.integer_array_t is
    variable result : work.common_pkg.integer_array_t(0 to 2**width - 1) := (others => 0);
  begin
    for i in result'range loop
      exit when 2**i - 1 > result'length;
      result(2**i - 1) := i;
    end loop;
    return result;
  end;

  ---------------
  -- Constants --
  ---------------
  constant logger            : logger_t := get_logger("dut");
  constant INPUT_BYTE_WIDTH  : natural := (INPUT_DATA_WIDTH + 7) / 8;
  constant OUTPUT_BYTE_WIDTH : natural := (OUTPUT_DATA_WIDTH + 7) / 8;

  -- When s_tlast is high, tkeep will flag how many bytes are actually valid. We'll put
  -- together a constant to mux
  constant TKEEP_TO_BYTES_IN : work.common_pkg.integer_array_t := get_tkeep_bytes_table(INPUT_BYTE_WIDTH);
  constant TKEEP_TO_BYTES_OUT : work.common_pkg.integer_array_t := get_tkeep_bytes_table(OUTPUT_BYTE_WIDTH);

  -----------
  -- Types --
  -----------

  -------------
  -- Signals --
  -------------
  signal s_first_word : std_logic;
  signal s_data_valid : std_logic;
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
    signal dbg_tmp          : std_logic_vector(2*(INPUT_DATA_WIDTH + OUTPUT_DATA_WIDTH) - 1 downto 0);
    signal dbg_bit_cnt      : natural range 0 to dbg_tmp'length - 1;
    signal dbg_flush_buffer : boolean := False;
  begin

    process(clk)
      variable tmp          : std_logic_vector(2*(INPUT_DATA_WIDTH + OUTPUT_DATA_WIDTH) - 1 downto 0);
      variable bit_cnt      : natural range 0 to tmp'length - 1;
      variable flush_buffer : boolean := False;
    begin
      if rising_edge(clk) then

        -- De-assert tvalid when data in being sent and no more data, except when we're
        -- flushing the output buffer
        if m_tready = '1' and (bit_cnt >= OUTPUT_DATA_WIDTH or flush_buffer) then
          if m_tlast_i = '1' then
            flush_buffer := False;
          end if;
          m_tvalid_i <= '0';
          m_tlast_i  <= '0';
        elsif m_tvalid_i = '1' then
          debug(logger, sformat("bit_cnt=%d, tmp=%r, not de asserting", fo(bit_cnt), fo(tmp)));
        end if;

        -- Handling incoming data
        if s_data_valid = '1' then
          debug(logger, sformat("bit_cnt=%d, tmp=%r", fo(bit_cnt), fo(tmp)));

          s_tready_i <= '0'; -- Each incoming word will generate at least 1 output word

          -- Need to assign data before bit_cnt (it's a variable)
          tmp(INPUT_DATA_WIDTH + bit_cnt - 1 downto bit_cnt) := s_tdata;
          if s_tlast = '0' then
            bit_cnt := bit_cnt + INPUT_DATA_WIDTH;
          else
            -- Last word, add the appropriate number of bits
            bit_cnt := bit_cnt + 8*TKEEP_TO_BYTES_IN(to_integer(unsigned(s_tkeep)));
          end if;

          if s_first_word = '1' then
            m_tid <= s_tid;
          end if;

          -- Upon receiving the last input word, mark 
          if s_tlast = '1' then
            flush_buffer := True;
          end if;

          debug(logger, sformat("bit_cnt=%d || tmp=%r || %r", fo(bit_cnt), fo(tmp), fo(flush_buffer)));

        end if;

        if bit_cnt >= OUTPUT_DATA_WIDTH or flush_buffer then
          m_tvalid_i <= '1';
          m_tdata    <= tmp(OUTPUT_DATA_WIDTH - 1 downto 0);

          -- Consume the data we're writing
          tmp        := (OUTPUT_DATA_WIDTH - 1 downto 0 => 'U') & tmp(tmp'length - 1 downto OUTPUT_DATA_WIDTH);

          -- Work out if the next word will be the last
          if flush_buffer then
            -- 
            if bit_cnt = OUTPUT_DATA_WIDTH then
              m_tlast_i <= '1';
              m_tkeep   <= (others => '1');

              bit_cnt   := 0;

            elsif bit_cnt < OUTPUT_DATA_WIDTH then
              m_tlast_i <= '1';
              -- Fill in the bit mask appropriately
              m_tkeep   <= (m_tkeep'length - 1 downto (bit_cnt + 7)/8 => '0')
                           & ((bit_cnt + 7) / 8 - 1 downto 0 => '1');

              bit_cnt   := 0;

            else
              bit_cnt    := bit_cnt - OUTPUT_DATA_WIDTH;
            end if;

          else
            bit_cnt    := bit_cnt - OUTPUT_DATA_WIDTH;
          end if;

          debug(logger, sformat("bit_cnt=%d || tmp=%r || %r", fo(bit_cnt), fo(tmp), fo(flush_buffer)));

          -- flush_buffer := False;
          -- debug(logger, sformat("bit_cnt=%d, tmp=%r", fo(bit_cnt), fo(tmp)));

        end if;

        -- Input should always be ready if there's room for data to be received
        if tmp'length - bit_cnt > INPUT_DATA_WIDTH then
          s_tready_i <= '1';
        end if;

        dbg_tmp          <= tmp;
        dbg_bit_cnt      <= bit_cnt;
        dbg_flush_buffer <= flush_buffer;

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
