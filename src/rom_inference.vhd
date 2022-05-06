--
-- FPGA core library
--
-- Copyright 2020-2022 by Andre Souto (suoto)
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
    rddata : out std_logic_vector(get_table_entry_width(ROM_DATA) - 1 downto 0));
end rom_inference;

architecture rom_inference of rom_inference is

  constant ROM : std_logic_array_t := ROM_DATA;
  constant ADDR_WIDTH : natural := numbits(ROM'length);
  constant DATA_WIDTH : natural := get_table_entry_width(ROM_DATA);

  attribute ROM_STYLE : string;
  constant RESOLVED_ROM_TYPE : string := get_ram_style(ROM_TYPE, ADDR_WIDTH, DATA_WIDTH);
  attribute ROM_STYLE of ROM : constant is RESOLVED_ROM_TYPE;

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

  rddata_async <= (others => 'U') when has_undefined(addr)                                    else
                  ROM(to_integer(addr_uns)) when addr_uns >= ROM'low and addr_uns <= ROM'high else
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
        if addr_uns >= ROM'low and addr_uns <= ROM'high then
          rddata_sync <= ROM(to_integer(addr_uns));
        else
          rddata_sync <= (others => 'U');
        end if;
      end if;
    end if;
  end process;

end rom_inference;
