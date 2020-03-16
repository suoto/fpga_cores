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
--
-- FPGA Cores is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with FPGA Cores.  If not, see <http://www.gnu.org/licenses/>.

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

library osvvm;
use osvvm.RandomPkg.all;

library str_format;
use str_format.str_format_pkg.all;

library fpga_cores;
use fpga_cores.common_pkg.all;

-- use work.testbench_utils_pkg.all;
use work.axi_stream_bfm_pkg.all;

------------------------
-- Entity declaration --
------------------------
entity axi_stream_bfm is
  generic (
    NAME       : string := AXI_STREAM_MASTER_DEFAULT_NAME;
    DATA_WIDTH : natural := 16;
    ID_WIDTH   : natural := 8);
  port (
    -- Usual ports
    clk      : in  std_logic;
    rst      : in  std_logic;
    -- AXI stream output
    m_tready : in  std_logic;
    m_tdata  : out std_logic_vector(DATA_WIDTH - 1 downto 0);
    m_tkeep  : out std_logic_vector((DATA_WIDTH + 7) / 8 - 1 downto 0) := (others => '0');
    m_tid    : out std_logic_vector(ID_WIDTH - 1 downto 0) := (others => '0');
    m_tvalid : out std_logic;
    m_tlast  : out std_logic);
end axi_stream_bfm;

architecture axi_stream_bfm of axi_stream_bfm is

  ---------------
  -- Constants --
  ---------------
  constant self            : actor_t  := new_actor(NAME);
  constant logger          : logger_t := get_logger(NAME);

  constant DATA_BYTE_WIDTH : natural := (DATA_WIDTH + 7) / 8;

  -------------
  -- Signals --
  -------------
  signal wr_en       : boolean := True;
  signal probability : real range 0.0 to 1.0 := 1.0;

begin

  -------------------
  -- Port mappings --
  -------------------

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------

  ---------------
  -- Processes --
  ---------------
  main_p : process
    variable msg : msg_t;

    ------------------------------------------------------------------
    procedure write (
      constant data : std_logic_vector(DATA_WIDTH - 1 downto 0);
      constant mask : std_logic_vector(DATA_BYTE_WIDTH - 1 downto 0);
      variable id   : std_logic_vector(ID_WIDTH - 1 downto 0);
      constant last : boolean := False) is
    begin
      debug(sformat("Writing: %r %r %s", fo(data), fo(mask), fo(last)));

      if not wr_en then
        wait until wr_en;
      end if;

      m_tdata   <= data;
      m_tkeep   <= mask;
      m_tid     <= id;
      m_tvalid  <= '1';
      if last then
        m_tlast <= '1';
      end if;

      wait until m_tvalid = '1' and m_tready = '1' and rising_edge(clk);

      m_tdata  <= (others => 'U');
      m_tkeep  <= (others => 'U');
      m_tid    <= (others => 'U');
      m_tvalid <= '0';
      m_tlast  <= '0';
    end;

    ------------------------------------------------------------------------------------
    procedure write_frame ( constant frame : axi_stream_frame_t ) is
      variable word       : std_logic_vector(DATA_WIDTH - 1 downto 0);
      variable mask       : std_logic_vector(DATA_BYTE_WIDTH - 1 downto 0);
      variable byte       : natural;
      variable id         : std_logic_vector(ID_WIDTH - 1 downto 0);
      constant percentage : natural := natural(100.0*frame.probability);
    begin
      info(logger, sformat("Setting duty cycle to %d\%", fo(percentage)));
      probability <= frame.probability;

      id := frame.id;

      for i in 0 to frame.data'length - 1 loop
        byte := i mod DATA_BYTE_WIDTH;

        word(8*(byte + 1) - 1 downto 8*byte) := frame.data(i);

        if ((i + 1) mod DATA_BYTE_WIDTH) = 0 then
          if i /= frame.data'length - 1 then
            write(word, (others => '0'), id, False);
          else
            write(word, (others => '1'), id, True);
          end if;

          word := (others => 'U');
          id   := (others => 'U');
        end if;
      end loop;

      if word = (word'range => 'U') then
        return;
      end if;

      mask                := (others => '0');
      mask(byte downto 0) := (others => '1');

      write(word, mask, id, True);

    end;

    ------------------------------------------------------------------------------------

  begin
    m_tvalid <= '0';
    m_tlast <= '0';

    receive(net, self, msg);
    write_frame(pop(msg));
    acknowledge(net, msg);

  end process;

  duty_cycle_p : process(clk, rst)
    variable rand : RandomPType;
  begin
    if rst = '1' then
      rand.InitSeed(name);
      wr_en <= False;
    elsif rising_edge(clk) then
      wr_en <= rand.RandReal(1.0) < probability;
    end if;
  end process;

end axi_stream_bfm;
