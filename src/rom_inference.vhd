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

---------------------------------
-- Block name and description --
--------------------------------
-- Simple single port ROM inference

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
    ROM_DATA     : std_logic_array_t;
    ROM_TYPE     : ram_type_t := auto;
    OUTPUT_DELAY : natural := 1);
  port (
    clk    : in  std_logic;
    clken  : in  std_logic;
    addr   : in  std_logic_vector(numbits(ROM_DATA'length) - 1 downto 0);
    rddata : out std_logic_vector(ROM_DATA(0)'length - 1 downto 0));

  constant ADDR_WIDTH : natural := numbits(ROM_DATA'length);
  constant DATA_WIDTH : natural := ROM_DATA(0)'length;

  attribute ROM_STYLE : string;
  constant RESOLVED_ROM_TYPE : string := get_ram_style(ROM_TYPE, ADDR_WIDTH, DATA_WIDTH);
  attribute ROM_STYLE of ROM_DATA : constant is RESOLVED_ROM_TYPE;
end rom_inference;

architecture rom_inference of rom_inference is

  -------------
  -- Signals --
  -------------
  signal addr_uns     : unsigned(addr'range);
  signal rddata_async : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal rddata_sync  : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal rddata_delay : std_logic_vector(DATA_WIDTH - 1 downto 0);

begin

  assert OUTPUT_DELAY /= 0 or RESOLVED_ROM_TYPE /= "bram"
    report "Can't use ROM_TYPE " & quote(RESOLVED_ROM_TYPE) & " with output delay set to " & integer'image(OUTPUT_DELAY)
    severity Failure;

  ------------------
  -- Port mappings --
  -------------------
  gen_sr_delay : if OUTPUT_DELAY > 1 generate
    rddata_a_delay_u : entity work.sr_delay
      generic map (
        DELAY_CYCLES  => OUTPUT_DELAY - 1,
        DATA_WIDTH    => DATA_WIDTH,
        EXTRACT_SHREG => False)
      port map (
        clk     => clk,
        clken   => clken,

        din     => rddata_sync,
        dout    => rddata_delay);
    end generate;

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  addr_uns     <= unsigned(addr);

  rddata_async <= ROM_DATA(to_integer(addr_uns)) when addr_uns >= ROM_DATA'low and addr_uns <= ROM_DATA'high else
                  (others => 'U');

  rddata <= rddata_async when OUTPUT_DELAY = 0 else
            rddata_sync when OUTPUT_DELAY = 1 else
            rddata_delay;

  ---------------
  -- Processes --
  ---------------
  port_a : process(clk)
  begin
    if clk'event and clk = '1' then
      if clken = '1' then
        if addr_uns >= ROM_DATA'low and addr_uns <= ROM_DATA'high then
          rddata_sync <= ROM_DATA(to_integer(addr_uns));
        else
          rddata_sync <= (others => 'U');
        end if;
      end if;
    end if;
  end process;

end rom_inference;
