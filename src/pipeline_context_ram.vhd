--
-- DVB FPGA
--
-- Copyright 2019 by Suoto <andre820@gmail.com>
--
-- This file is part of DVB FPGA.
--
-- DVB FPGA is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- DVB FPGA is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with DVB FPGA.  If not, see <http://www.gnu.org/licenses/>.

---------------
-- Libraries --
---------------
library	ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

------------------------
-- Entity declaration --
------------------------
entity pipeline_context_ram is
  generic (
    ADDR_WIDTH          : positive := 16;
    DATA_WIDTH          : positive := 16;
    RAM_INFERENCE_STYLE : string   := "auto");
  port (
    clk         : in  std_logic;
    -- Checkout request interface
    en_in       : in  std_logic;
    addr_in     : in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
    -- Data checkout output
    en_out      : out std_logic;
    addr_out    : out std_logic_vector(ADDR_WIDTH - 1 downto 0);
    context_out : out std_logic_vector(DATA_WIDTH - 1 downto 0);
    -- Updated data input
    context_in  : in  std_logic_vector(DATA_WIDTH - 1 downto 0));
end pipeline_context_ram;

architecture pipeline_context_ram of pipeline_context_ram is

  -----------
  -- Types --
  -----------
  type addr_array_t is array (natural range <>) of std_logic_vector(ADDR_WIDTH - 1 downto 0);

  -------------
  -- Signals --
  -------------
  signal ram_rddata     : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal context_in_reg : std_logic_vector(DATA_WIDTH - 1 downto 0);

  signal addr_sr        : addr_array_t(2 downto 0);
  signal en_sr          : std_logic_vector(2 downto 0);

  signal addr_out_i     : std_logic_vector(ADDR_WIDTH - 1 downto 0);

begin

  -------------------
  -- Port mappings --
  -------------------
  ram_u : entity work.ram_inference
    generic map (
      ADDR_WIDTH          => ADDR_WIDTH,
      DATA_WIDTH          => DATA_WIDTH,
      RAM_INFERENCE_STYLE => RAM_INFERENCE_STYLE,
      OUTPUT_DELAY        => 1)
    port map (
      -- Port A
      clk_a     => clk,
      clken_a   => '1',
      wren_a    => en_sr(1),
      addr_a    => addr_sr(1),
      wrdata_a  => context_in,
      rddata_a  => open,

      -- Port B
      clk_b     => clk,
      clken_b   => '1',
      addr_b    => addr_in,
      rddata_b  => ram_rddata);

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  -- Loop data until
  context_out <= context_in when addr_out = addr_in and en_in = '1' else
                 context_in_reg when addr_out = addr_sr(2) and en_sr(2) = '1' else
                 ram_rddata;

  en_out     <= en_sr(0);
  addr_out_i <= addr_sr(0);

  addr_out   <= addr_out_i;

  ---------------
  -- Processes --
  ---------------
  process(clk)
  begin
    if rising_edge(clk) then
      addr_sr <= addr_sr(addr_sr'length - 2 downto 0) & addr_in;
      en_sr   <= en_sr(en_sr'length - 2 downto 0) & en_in;
    end if;
  end process;

end pipeline_context_ram;
