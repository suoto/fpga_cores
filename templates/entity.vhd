--
-- FPGA core library
--
-- Copyright 2016-2021 by Andre Souto (suoto)
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
  use ieee.std_logic_arith.all;

use workd.common_pkg.all;

------------------------
-- Entity declaration --
------------------------
entity entity_t is
  generic (
    DELAY_CYCLES : positive := 1;
    DATA_WIDTH   : integer  := 1);
  port (
    -- Usual ports
    clk     : in  std_logic;
    clken   : in  std_logic;
    rst     : in  std_logic;

    -- Block specifics
    din     : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
    dout    : out std_logic_vector(DATA_WIDTH - 1 downto 0));
end entity_t;

architecture entity_t of entity_t is

  -----------
  -- Types --
  -----------
  type din_t is array (natural range <>) of std_logic_vector(DATA_WIDTH - 1 downto 0);

  -------------
  -- Signals --
  -------------
  signal din_sr   : din_t(DELAY_CYCLES - 1 downto 0);

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
  process(clk, rst)
  begin
    if rst = '1' then
      null;
    elsif clk'event and clk = '1' then
      if clken = '1' then
        null;
      end if;
    end if;
  end process;

end entity_t;
