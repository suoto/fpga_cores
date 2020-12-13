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

-- vunit: run_all_in_same_sim

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

library fpga_cores_sim;
use fpga_cores_sim.axi_stream_bfm_pkg.all;

library fpga_cores;
use fpga_cores.axi_pkg.all;
use fpga_cores.common_pkg.all;

entity axi_stream_frame_fifo_tb is
  generic (runner_cfg : string);
end axi_stream_frame_fifo_tb;

architecture axi_stream_frame_fifo_tb of axi_stream_frame_fifo_tb is

  constant CLK_PERIOD         : time := 5 ns;
  constant FIFO_DEPTH         : integer := 256;
  constant DATA_WIDTH         : integer := 8;

  shared variable wr_data_gen : RandomPType;
  shared variable rd_data_gen : RandomPType;
  shared variable random_gen  : RandomPType;

  signal clk   : std_logic := '0';
  signal rst   : std_logic;

  signal m_axi : axi_stream_data_bus_t(tdata(DATA_WIDTH - 1 downto 0));
  signal s_axi : axi_stream_data_bus_t(tdata(DATA_WIDTH - 1 downto 0));

  signal entries  : std_logic_vector(numbits(FIFO_DEPTH) downto 0);
  signal empty    : std_logic;
  signal full     : std_logic;

begin

  -------------------
  -- Port mappings --
  -------------------
  axi_master_bfm_u : entity fpga_cores_sim.axi_stream_bfm
    generic map (
      TDATA_WIDTH => DATA_WIDTH,
      TUSER_WIDTH => 0,
      TID_WIDTH   => 0)
    port map (
      -- Usual ports
      clk      => clk,
      rst      => rst,
      -- AXI stream output
      m_tready => m_axi.tready,
      m_tdata  => m_axi.tdata,
      m_tvalid => m_axi.tvalid,
      m_tlast  => m_axi.tlast);


  dut : entity fpga_cores.axi_stream_frame_fifo
    generic map (
      FIFO_DEPTH => FIFO_DEPTH,
      DATA_WIDTH => DATA_WIDTH)
    port map (
      -- Write port
      clk      => clk,
      rst      => rst,

      entries  => entries,
      empty    => empty,
      full     => full,

      -- Write side
      s_tvalid => m_axi.tvalid,
      s_tready => m_axi.tready,
      s_tdata  => m_axi.tdata,
      s_tlast  => m_axi.tlast,

      -- Read side
      m_tvalid => s_axi.tvalid,
      m_tready => s_axi.tready,
      m_tdata  => s_axi.tdata,
      m_tlast  => s_axi.tlast);


  -- m_axi.tdata <= (others => '0');
  s_axi.tready <= '1';

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  clk <= not clk after CLK_PERIOD/2;
  rst <= '1', '0' after 16*CLK_PERIOD;

  test_runner_watchdog(runner, 20 us);

  ---------------
  -- Processes --
  ---------------
  main : process
    variable axi_master : axi_stream_bfm_t := create_bfm;
    --
    procedure walk (constant steps : natural := 1) is
    begin
      if steps /= 0 then
        for step in 0 to steps - 1 loop
          wait until rising_edge(clk);
        end loop;
      end if;
    end procedure;

    --
    impure function generate_frame ( constant length : natural ) return std_logic_vector_2d_t is
      variable frame : std_logic_vector_2d_t(0 to length - 1)(DATA_WIDTH - 1 downto 0);
    begin
      for i in frame'range loop
        frame(i) := wr_data_gen.RandSlv(DATA_WIDTH);
      end loop;
      return frame;
    end;
    --
    procedure write_random_frame (constant length : natural ) is
      constant frame : std_logic_vector_2d_t := generate_frame(length);
    begin
      info(sformat("Writing frame with length=%d", fo(length)));
      axi_bfm_write(net,
        bfm      => axi_master,
        data     => frame,
        blocking => True);
      info("Done");
    end;

      --
      variable stat   : checker_stat_t;
      -- variable filter : log_filter_t;
    begin

        -- Start both wr and rd data random generators with the same seed so
        -- we get the same sequence
        wr_data_gen.InitSeed("some_seed");
        rd_data_gen.InitSeed("some_seed");

        -- checker_init(display_format => verbose,
        --              file_name      => join(output_path(runner_cfg), "error.csv"),
        --              file_format    => verbose_csv);

        -- logger_init(display_format => verbose,
        --             file_name      => join(output_path(runner_cfg), "log.csv"),
        --             file_format    => verbose_csv);
        -- stop_level((debug, verbose), display_handler, filter);
        test_runner_setup(runner, runner_cfg);

        wait until rst = '0';

        walk(16);

        while test_suite loop
          if run("random_4_word_frame") then
            write_random_frame(FIFO_DEPTH/4);
          end if;
          walk(2*FIFO_DEPTH);
        end loop;

        if not active_python_runner(runner_cfg) then
            get_checker_stat(stat);
            warning(LF & "Result:" & LF & to_string(stat));
        end if;

        test_runner_cleanup(runner);
        wait;
    end process;

    -- rd_side : process
    -- begin

    --     wait until rst = '0';

    --     while True loop
    --         walk(1);
    --         if rd_dv = '1' then
    --             check_equal(rd_data, rd_data_gen.RandSlv(DATA_WIDTH));
    --         end if;
    --     end loop;

    --     wait;
    -- end process;

    -- rd_en_randomize : process
    -- begin
    --     rd_en <= '0';
    --     wait until rst = '0';
    --     walk(10);

    --     if RD_EN_RANDOM = 0 then
    --         rd_en <= '1';
    --         wait;
    --     else
    --         while True loop
    --             rd_en <= '1';
    --             walk(random_gen.RandInt(RD_EN_RANDOM));
    --             rd_en <= '0';
    --             walk(random_gen.RandInt(RD_EN_RANDOM));
    --         end loop;
    --     end if;
    -- end process;

end axi_stream_frame_fifo_tb;

