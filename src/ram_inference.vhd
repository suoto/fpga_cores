--
-- FPGA core library
--
-- Copyright 2014-2022 by Andre Souto (suoto)
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
    DEPTH         : natural := 16;
    DATA_WIDTH    : natural := 16;
    RAM_TYPE      : string := "auto";
    INITIAL_VALUE : std_logic_array_t(0 to DEPTH - 1)(DATA_WIDTH - 1 downto 0) := (others => (others => '0'));
    OUTPUT_DELAY  : natural := 1);
  port (
    -- Port A
    clk_a     : in  std_logic;
    en_a      : in  std_logic := '1';
    wren_a    : in  std_logic;
    addr_a    : in  std_logic_vector(numbits(DEPTH) - 1 downto 0);
    wrdata_a  : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
    rddata_a  : out std_logic_vector(DATA_WIDTH - 1 downto 0);

    -- Port B
    clk_b     : in  std_logic;
    en_b      : in  std_logic := '1';
    addr_b    : in  std_logic_vector(numbits(DEPTH) - 1 downto 0);
    rddata_b  : out std_logic_vector(DATA_WIDTH - 1 downto 0));
end ram_inference;

architecture ram_inference of ram_inference is

  -------------
  -- Signals --
  -------------
  signal ram                 : std_logic_array_t(0 to DEPTH - 1)(DATA_WIDTH - 1 downto 0) := INITIAL_VALUE;

  signal rddata_a_async      : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal rddata_a_sync       : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal rddata_a_delay      : std_logic_vector(DATA_WIDTH - 1 downto 0);

  signal rddata_b_async      : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal rddata_b_sync       : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal rddata_b_delay      : std_logic_vector(DATA_WIDTH - 1 downto 0);

  attribute RAM_STYLE        : string;
  attribute RAM_STYLE of ram : signal is RAM_TYPE;

begin

  assert is_valid(RAM_TYPE)
    report "Invalid RAM_TYPE: " & quote(RAM_TYPE)
    severity Warning;

  assert OUTPUT_DELAY /= 0 or RAM_TYPE /= "bram"
    report "Can't use RAM_TYPE " & quote(RAM_TYPE) & " with output delay set to " & integer'image(OUTPUT_DELAY)
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

        din_en  => '1',
        din     => rddata_a_sync,
        dout    => rddata_a_delay);

    rddata_b_delay_u : entity work.sr_delay
      generic map (
        DELAY_CYCLES  => OUTPUT_DELAY - 1,
        DATA_WIDTH    => DATA_WIDTH,
        EXTRACT_SHREG => False)
      port map (
        clk     => clk_b,

        din_en  => '1',
        din     => rddata_b_sync,
        dout    => rddata_b_delay);
    end generate;

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  rddata_a_async <= (others => 'U') when has_undefined(addr_a) or unsigned(addr_a) >= DEPTH else
                    ram(to_integer(unsigned(addr_a)));
  rddata_b_async <= (others => 'U') when has_undefined(addr_b) or unsigned(addr_b) >= DEPTH else
                    ram(to_integer(unsigned(addr_b)));

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
      if to_integer(unsigned(addr_a)) < DEPTH and not has_undefined(addr_a) and en_a = '1' then
        rddata_a_sync <= ram(to_integer(unsigned(addr_a)));
      end if;
      if wren_a = '1' then
        ram(to_integer(unsigned(addr_a))) <= wrdata_a;
      end if;
    end if;
  end process;

  port_b : process(clk_b)
  begin
    if clk_b'event and clk_b = '1' then
      if to_integer(unsigned(addr_b)) < DEPTH and not has_undefined(addr_b) and en_b = '1' then
        rddata_b_sync <= ram(to_integer(unsigned(addr_b)));
      end if;
    end if;
  end process;

end ram_inference;
