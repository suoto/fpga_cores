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
    RAM_TYPE     : string  := "auto";
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

  -- Assign block RAM if the RAM size is bigger than 150% of a 18KB block RAM
  function get_ram_style return string is
    constant BRAM_SIZE     : integer := 18 * 1024;
    constant BRAM_TRESHOLD : real    := 1.5;

    constant size : natural := (2**ADDR_WIDTH) * DATA_WIDTH;
  begin
    if RAM_TYPE /= "auto"  then
      return RAM_TYPE;
    end if;

    if real(size / BRAM_SIZE) > BRAM_TRESHOLD then
      return "block";
    end if;

    return "distributed";

  end function get_ram_style;

  constant RESOLVED_RAM_STYLE : string := get_ram_style;

  -----------
  -- Types --
  -----------
  type data_array_t is array (natural range <>) of std_logic_vector(DATA_WIDTH - 1 downto 0);

  -------------
  -- Signals --
  -------------
  signal ram        : data_array_t(0 to 2**ADDR_WIDTH - 1);
  signal rddata_a_i : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal rddata_b_i : std_logic_vector(DATA_WIDTH - 1 downto 0);

  attribute RAM_STYLE        : string;
  attribute RAM_STYLE of ram : signal is RESOLVED_RAM_STYLE;

begin

  assert RAM_TYPE = "auto"
      or RAM_TYPE = "block"
      or RAM_TYPE = "distributed"
    report "Invalid RAM_STYLE: " & quote(RAM_TYPE)
    severity Warning;

  -------------------
  -- Port mappings --
  -------------------
  gen_not_bram_delay : if RESOLVED_RAM_STYLE /= "block" generate
    rddata_a_delay : entity work.sr_delay
      generic map (
        DELAY_CYCLES => OUTPUT_DELAY,
        DATA_WIDTH   => DATA_WIDTH)
      port map (
        clk     => clk_a,
        clken   => clken_a,

        din     => rddata_a_i,
        dout    => rddata_a);

    rddata_a_i <= ram(to_integer(unsigned(addr_a)));

  end generate;

  -- Need this workaround so that Vivado manages to infer a block RAM when specified
  gen_bram_delay : if RESOLVED_RAM_STYLE = "block" generate
    assert OUTPUT_DELAY /= 0
      report "Can't use RAM_TYPE " & quote(RESOLVED_RAM_STYLE) & " with output delay set to " & integer'image(OUTPUT_DELAY)
      severity Failure;

    rddata_a_delay : entity work.sr_delay
      generic map (
        DELAY_CYCLES => OUTPUT_DELAY - 1,
        DATA_WIDTH   => DATA_WIDTH)
      port map (
        clk     => clk_a,
        clken   => clken_a,

        din     => rddata_a_i,
        dout    => rddata_a);

    process(clk_a)
    begin
      if clk_a'event and clk_a = '1' then
        if clken_a = '1' then
          rddata_a_i <= ram(to_integer(unsigned(addr_a)));
        end if;
      end if;
    end process;

  end generate;

  rddata_b_delay : entity work.sr_delay
    generic map (
      DELAY_CYCLES => OUTPUT_DELAY,
      DATA_WIDTH   => DATA_WIDTH)
    port map (
      clk     => clk_b,
      clken   => clken_b,

      din     => rddata_b_i,
      dout    => rddata_b);

  rddata_b_i <= ram(to_integer(unsigned(addr_b)));

  ---------------
  -- Processes --
  ---------------
  port_a : process(clk_a)
  begin
    if clk_a'event and clk_a = '1' then
      if clken_a = '1' then
        if wren_a = '1' then
          ram(to_integer(unsigned(addr_a))) <= wrdata_a;
        end if;
      end if;
    end if;
  end process;

end ram_inference;
