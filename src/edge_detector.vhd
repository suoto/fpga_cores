--
-- FPGA core library
--
-- Copyright 2014-2021 by Andre Souto (suoto)
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


--------------------------
-- Simple edge detector --
--------------------------

---------------
-- Libraries --
---------------
library ieee;
use ieee.std_logic_1164.all;  

------------------------
-- Entity declaration --
------------------------
entity edge_detector is
  generic (
    SYNCHRONIZE_INPUT : boolean := false;
    OUTPUT_DELAY      : natural := 1);
  port (
    -- Usual ports
    clk     : in  std_logic;
    clken   : in  std_logic;

    -- 
    din     : in  std_logic;
    -- Edges detected
    rising  : out std_logic;
    falling : out std_logic;
    toggle  : out std_logic);
end edge_detector;

architecture edge_detector of edge_detector is

  -------------
  -- Signals --
  -------------
  signal din_i     : std_logic;
  signal din_d     : std_logic;
  signal rising_i  : std_logic;
  signal falling_i : std_logic;
  signal toggle_i  : std_logic;

begin

  -------------------
  -- Port mappings --
  -------------------
  gsync_in : if SYNCHRONIZE_INPUT generate
    sync_in : entity work.synchronizer
      generic map (
        SYNC_STAGES => 1,
        DATA_WIDTH  => 1)
      port map (
        clk     => clk,
        clken   => clken,

        din(0)  => din,
        dout(0) => din_i);
  end generate gsync_in;

  output_a : entity work.sr_delay
    generic map (
      DELAY_CYCLES => OUTPUT_DELAY,
      DATA_WIDTH   => 3)
    port map (
      clk     => clk,
      clken   => clken,

      din(0)  => rising_i,
      din(1)  => falling_i,
      din(2)  => toggle_i,

      dout(0) => rising,
      dout(1) => falling,
      dout(2) => toggle);

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  ngsync_in : if not SYNCHRONIZE_INPUT generate
    din_i <= din;
  end generate ngsync_in;

  rising_i  <= '1' when din_i = '1' and din_d /= '1' else '0';
  falling_i <= '1' when din_i /= '1' and din_d = '1' else '0';
  toggle_i  <= rising_i or falling_i;

  ---------------
  -- Processes --
  ---------------
  process(clk)
  begin
    if clk'event and clk = '1' then
      if clken = '1' then
        din_d <= din_i;
      end if;
    end if;
  end process;

end edge_detector;

