--
-- FPGA Cores -- An HDL core library
--
-- Copyright 2014 by Andre Souto (suoto)
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

use work.common_pkg.all;

------------------------
-- Entity declaration --
------------------------
entity axi_stream_width_converter is
  generic (
    INPUT_DATA_WIDTH  : natural     := 32;
    OUTPUT_DATA_WIDTH : natural     := 16;
    AXI_TID_WIDTH     : natural     := 0;
    ENDIANNESS        : endianess_t := RIGHT_FIRST;
    IGNORE_TKEEP      : boolean     := False);
  port (
    -- Usual ports
    clk      : in  std_logic;
    rst      : in  std_logic;
    -- AXI stream input
    s_tready : out std_logic;
    s_tdata  : in  std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);
    s_tkeep  : in  std_logic_vector((INPUT_DATA_WIDTH + 7) / 8 - 1 downto 0) := (others => 'U');
    s_tid    : in  std_logic_vector(AXI_TID_WIDTH - 1 downto 0) := (others => 'U');
    s_tvalid : in  std_logic;
    s_tlast  : in  std_logic;
    -- AXI stream output
    m_tready : in  std_logic;
    m_tdata  : out std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);
    m_tkeep  : out std_logic_vector((OUTPUT_DATA_WIDTH + 7) / 8 - 1 downto 0) := (others => 'U');
    m_tid    : out std_logic_vector(AXI_TID_WIDTH - 1 downto 0) := (others => 'U');
    m_tvalid : out std_logic;
    m_tlast  : out std_logic := '0');
end axi_stream_width_converter;

architecture axi_stream_width_converter of axi_stream_width_converter is

  ---------------
  -- Constants --
  ---------------
  constant INPUT_BYTE_WIDTH  : natural := (INPUT_DATA_WIDTH + 7) / 8;
  constant OUTPUT_BYTE_WIDTH : natural := (OUTPUT_DATA_WIDTH + 7) / 8;
  -- TKEEP is not supported if tdata is not multiple of 8 bits
  constant HANDLE_TKEEP      : boolean := INPUT_DATA_WIDTH mod 8 = 0 and not IGNORE_TKEEP;

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
  function get_tkeep ( constant valid_bytes : natural ) return std_logic_vector is
    variable result : std_logic_vector(OUTPUT_BYTE_WIDTH - 1 downto 0) := (others => '0');
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
  signal m_tdata_i    : std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);
  signal s_tready_i   : std_logic;
  signal m_tvalid_i   : std_logic;
  signal m_tlast_i    : std_logic;

begin

  g_pass_through : if INPUT_DATA_WIDTH = OUTPUT_DATA_WIDTH generate -- {{
    signal s_tid_reg  : std_logic_vector(AXI_TID_WIDTH - 1 downto 0);
  begin

    s_tready_i <= m_tready;
    m_tdata_i  <= s_tdata;
    m_tkeep    <= s_tkeep;
    m_tvalid_i <= s_tvalid;
    m_tlast_i  <= s_tlast;
    m_tid      <= s_tid when s_first_word = '1' else s_tid_reg;

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
    signal s_tdata_adj   : std_logic_vector(8*INPUT_BYTE_WIDTH - 1 downto 0);
    signal s_tkeep_adj   : std_logic_vector(INPUT_BYTE_WIDTH - 1 downto 0);
    signal dbg_tmp       : std_logic_vector(2*(INPUT_DATA_WIDTH + OUTPUT_DATA_WIDTH) - 1 downto 0);
    signal dbg_bit_cnt   : unsigned(numbits(dbg_tmp'length) - 1 downto 0);
    signal dbg_flush_req : boolean := False;
  begin

    -------------------
    -- Port mappings --
    -------------------
    g_tid_fifo : if AXI_TID_WIDTH > 0 generate
      signal wr_en : std_logic;
      signal rd_en : std_logic;
    begin
      wr_en <= s_first_word and s_data_valid;
      rd_en <= m_tlast_i and m_tvalid_i and m_tready;

      -- Need a small FIFO for the TID
      tid_fifo_u : entity work.sync_fifo
        generic map (
          -- FIFO configuration
          RAM_TYPE           => lut,
          DEPTH              => 4,
          DATA_WIDTH         => AXI_TID_WIDTH,
          UPPER_TRESHOLD     => 3,
          LOWER_TRESHOLD     => 1,
          EXTRA_OUTPUT_DELAY => 0)
        port map (
          -- Write port
          clk     => clk,
          clken   => '1',
          rst     => rst,

          -- Status
          full    => open,
          upper   => open,
          lower   => open,
          empty   => open,

          wr_en   => wr_en,
          wr_data => s_tid,

          -- Read port
          rd_en   => rd_en,
          rd_data => m_tid,
          rd_dv   => open);
    end generate;

    g_no_tid_fifo : if AXI_TID_WIDTH = 0 generate
      m_tid <= (others => 'U');
    end generate;

    s_tdata_adj <= (8*INPUT_BYTE_WIDTH - 1 downto INPUT_DATA_WIDTH => 'U') & s_tdata when ENDIANNESS = RIGHT_FIRST else
                   mirror_bits(s_tdata) & (8*INPUT_BYTE_WIDTH - 1 downto INPUT_DATA_WIDTH => 'U');

    s_tkeep_adj <= s_tkeep when ENDIANNESS = RIGHT_FIRST else mirror_bits(s_tkeep);

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
          if s_tlast = '1' and HANDLE_TKEEP then
            -- FIXME: This does not look very synth friendly, check how this gets mapped and refactor if needed
            -- Last word, add the appropriate number of bits
            for i in 0 to s_tkeep_adj'length - 1 loop
              if s_tkeep_adj(i) = '1' then
                tmp(8 + bit_cnt - 1 downto bit_cnt) := s_tdata_adj(8*(i + 1) - 1 downto 8*i);
                -- INPUT_DATA_WIDTH may or may not be a submultiple of 8
                if i = s_tkeep_adj'length - 1 and (INPUT_DATA_WIDTH mod 8) /= 0 then
                  bit_cnt := bit_cnt + (INPUT_DATA_WIDTH mod 8);
                else
                  bit_cnt := bit_cnt + 8;
                end if;
              end if;
            end loop;

          else
            tmp(8*INPUT_BYTE_WIDTH + bit_cnt - 1 downto bit_cnt) := s_tdata_adj;
            bit_cnt                                              := bit_cnt + INPUT_DATA_WIDTH;
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
          m_tdata_i  <= tmp(OUTPUT_DATA_WIDTH - 1 downto 0);
          m_tkeep    <= (others => '0');

          -- Work out if the next word will be the last and fill in the bit mask
          -- appropriately
          if bit_cnt <= OUTPUT_DATA_WIDTH and flush_req then
            m_tlast_i <= '1';
            if HANDLE_TKEEP then
                if OUTPUT_DATA_WIDTH < 8 then
                m_tkeep <= (others => '1');
              else
                m_tkeep <= get_tkeep((bit_cnt + 7) / 8);
              end if;
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
        dbg_bit_cnt   <= to_unsigned(bit_cnt, dbg_bit_cnt'length);
        dbg_flush_req <= flush_req;

        if rst = '1' then
          s_tready_i <= '1';
          m_tvalid_i <= '0';
          m_tlast_i  <= '0';
        end if;
      end if;
    end process;

  end generate g_downsize; -- }}

  g_upsize : if INPUT_DATA_WIDTH < OUTPUT_DATA_WIDTH generate -- {{
    assert False
      report "Conversion from " & integer'image(INPUT_DATA_WIDTH) & " to " & integer'image(OUTPUT_DATA_WIDTH) & " is not currently supported"
      severity Failure;
  end generate g_upsize; -- }}

  -------------------
  -- Port mappings --
  -------------------

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  s_data_valid <= s_tready_i and s_tvalid and not rst;
  m_data_valid <= m_tready and m_tvalid_i and not rst;

  m_tdata      <= (others => 'U')         when m_tvalid_i = '0'         else
                  m_tdata_i               when ENDIANNESS = RIGHT_FIRST else
                  mirror_bits(m_tdata_i);
  s_tready     <= s_tready_i;
  m_tvalid     <= m_tvalid_i;
  m_tlast      <= m_tlast_i and m_tvalid_i;

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
