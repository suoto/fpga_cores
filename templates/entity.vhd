--
-- hdl_lib -- A(nother) HDL library
--
-- Copyright 2016 by Andre Souto (suoto)
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
