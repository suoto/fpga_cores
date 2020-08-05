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
-- Simple dual port RAM inference

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
entity ram_inference is
  generic (
    ADDR_WIDTH   : natural := 16;
    DATA_WIDTH   : natural := 16;
    RAM_TYPE     : ram_type_t := auto;
    OUTPUT_DELAY : natural := 1);
  port (
    -- Port A
    clk_a     : in  std_logic;
    clken_a   : in  std_logic;
    wren_a    : in  std_logic;
    addr_a    : in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
    wrdata_a  : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
    rddata_a  : out std_logic_vector(DATA_WIDTH - 1 downto 0);

    -- Port B
    clk_b     : in  std_logic;
    clken_b   : in  std_logic;
    addr_b    : in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
    rddata_b  : out std_logic_vector(DATA_WIDTH - 1 downto 0));
end ram_inference;

architecture ram_inference of ram_inference is

  -----------
  -- Types --
  -----------
  type data_array_t is array (natural range <>) of std_logic_vector(DATA_WIDTH - 1 downto 0);

  -------------
  -- Signals --
  -------------
  signal ram                 : data_array_t(0 to 2**ADDR_WIDTH - 1);

  signal rddata_a_async      : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal rddata_a_sync       : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal rddata_a_delay      : std_logic_vector(DATA_WIDTH - 1 downto 0);

  signal rddata_b_async      : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal rddata_b_sync       : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal rddata_b_delay      : std_logic_vector(DATA_WIDTH - 1 downto 0);

  attribute RAM_STYLE : string;
  attribute RAM_STYLE of ram : signal is get_ram_style(RAM_TYPE, ADDR_WIDTH, DATA_WIDTH);

begin

  assert OUTPUT_DELAY /= 0 or ram'ram_style /= "bram"
    report "Can't use RAM_TYPE " & quote(ram'ram_style) & " with output delay set to " & integer'image(OUTPUT_DELAY)
    severity Failure;

  -------------------
  -- Port mappings --
  -------------------
  gen_sr_delay : if OUTPUT_DELAY > 1 generate
    rddata_a_delay_u : entity work.sr_delay
      generic map (
        DELAY_CYCLES  => OUTPUT_DELAY - 1,
        DATA_WIDTH    => DATA_WIDTH,
        EXTRACT_SHREG => False)
      port map (
        clk     => clk_a,
        clken   => clken_a,

        din     => rddata_a_sync,
        dout    => rddata_a_delay);

    rddata_b_delay_u : entity work.sr_delay
      generic map (
        DELAY_CYCLES  => OUTPUT_DELAY - 1,
        DATA_WIDTH    => DATA_WIDTH,
        EXTRACT_SHREG => False)
      port map (
        clk     => clk_b,
        clken   => clken_b,

        din     => rddata_b_sync,
        dout    => rddata_b_delay);
    end generate;

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  rddata_a_async <= ram(to_integer(unsigned(addr_a)));
  rddata_b_async <= ram(to_integer(unsigned(addr_b)));

  rddata_a <= rddata_a_async when OUTPUT_DELAY = 0 else
              rddata_a_sync when OUTPUT_DELAY = 1 else
              rddata_a_delay;

  rddata_b <= rddata_b_async when OUTPUT_DELAY = 0 else
              rddata_b_sync when OUTPUT_DELAY = 1 else
              rddata_b_delay;


  ---------------
  -- Processes --
  ---------------
  port_a : process(clk_a)
  begin
    if clk_a'event and clk_a = '1' then
      if clken_a = '1' then
        rddata_a_sync <= ram(to_integer(unsigned(addr_a)));
        if wren_a = '1' then
          ram(to_integer(unsigned(addr_a))) <= wrdata_a;
        end if;
      end if;
    end if;
  end process;

  port_b : process(clk_b)
  begin
    if clk_b'event and clk_b = '1' then
      if clken_b = '1' then
        rddata_b_sync <= ram(to_integer(unsigned(addr_b)));
      end if;
    end if;
  end process;

end ram_inference;
