--
-- DVB IP
--
-- Copyright 2020 by Suoto <andre820@gmail.com>
--
-- This file is part of the DVB IP.
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

use work.common_pkg.all;

------------------------
-- Entity declaration --
------------------------
entity rom_inference is
  generic (
    DATA                : std_logic_vector_2d_t;
    RAM_INFERENCE_STYLE : string  := "auto";
    OUTPUT_DELAY  : natural := 0
  );
  port (
    -- Usual ports
    clk  : in  std_logic;

    -- Block specifics
    addr : in  std_logic_vector(numbits(DATA'length) - 1 downto 0);
    dout : out std_logic_vector(DATA(DATA'low)'length - 1 downto 0));
end rom_inference;

architecture rom_inference of rom_inference is

  -- -- TODO: Check that this actually works
  -- attribute RAM_STYLE         : string;
  -- attribute RAM_STYLE of DATA : constant is RAM_INFERENCE_STYLE;

  ---------------
  -- Constants --
  ---------------
  constant DATA_WIDTH : natural := DATA(DATA'low)'length;

  -------------
  -- Signals --
  -------------
  signal addr_i : integer range 0 to DATA'length - 1;
  signal dout_i : std_logic_vector(dout'range);

begin

  -------------------
  -- Port mappings --
  -------------------
  delay_u : entity work.sr_delay
  generic map (
    DELAY_CYCLES  => OUTPUT_DELAY,
    DATA_WIDTH    => DATA_WIDTH,
    EXTRACT_SHREG => False)
  port map (
    clk     => clk,
    clken   => '1',

    din     => dout_i,
    dout    => dout);

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  addr_i <= to_integer(unsigned(addr));

  ---------------
  -- Processes --
  ---------------
  process(clk)
  begin
    if clk'event and clk = '1' then
      dout_i <= DATA(addr_i);
    end if;
  end process;

end rom_inference;
