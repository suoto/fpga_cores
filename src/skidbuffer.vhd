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


-- ##########################################################################
-- ## Based on Dan Gisselquist's skidbuffer.v the original can be found in ##
-- ## https://github.com/ZipCPU/wb2axip/blob/master/rtl/skidbuffer.v       ##
-- ##########################################################################

--------------------------------------------------------------------------------
--
-- Filename: 	skidbuffer.v
--
-- Project:	WB2AXIPSP: bus bridges and other odds and ends
--
-- Purpose:	A basic SKID buffer.
--
--	Skid buffers are required for high throughput AXI code, since the AXI
--	specification requires that all outputs be registered.  This means
--	that, if there are any stall conditions calculated, it will take a clock
--	cycle before the stall can be propagated up stream.  This means that
--	the data will need to be buffered for a cycle until the stall signal
--	can make it to the output.
--
--	Handling that buffer is the purpose of this core.
--
--	On one end of this core, you have the i_valid and i_data inputs to
--	connect to your bus interface.  There's also a registered o_ready
--	signal to signal stalls for the bus interface.
--
--	The other end of the core has the same basic interface, but it isn't
--	registered.  This allows you to interact with the bus interfaces
--	as though they were combinatorial logic, by interacting with this half
--	of the core.
--
--	If at any time the incoming !stall signal, i_ready, signals a stall,
--	the incoming data is placed into a buffer.  Internally, that buffer
--	is held in r_data with the r_valid flag used to indicate that valid
--	data is within it.
--
-- Parameters:
--	DW or data width
--		In order to make this core generic, the width of the data in the
--		skid buffer is parameterized
--
--	OPT_LOWPOWER
--		Forces both o_data and r_data to zero if the respective *VALID
--		signal is also low.  While this costs extra logic, it can also
--		be used to guarantee that any unused values aren't toggling and
--		therefore unnecessarily using power.
--
--		This excess toggling can be particularly problematic if the
--		bus signals have a high fanout rate, or a long signal path
--		across an FPGA.
--
--	OPT_OUTREG
--		Causes the outputs to be registered
--
--	OPT_PASSTHROUGH
--		Turns the skid buffer into a passthrough.  Used for formal
--		verification only.
--
-- Creator:	Dan Gisselquist, Ph.D.
--		Gisselquist Technology, LLC
--

---------------
-- Libraries --
---------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

------------------------
-- Entity declaration --
------------------------
entity skidbuffer is
  generic (
    DW              : natural :=8;
    OPT_LOWPOWER    : boolean := False;
    OPT_OUTREG      : boolean := True;
    OPT_PASSTHROUGH : boolean := False);
  port (
     i_clk   : in std_logic;
     i_reset : in std_logic;

     i_valid : in std_logic;
     o_ready : out std_logic;
     i_data  : in std_logic_vector(DW - 1 downto 0);

     o_valid : out std_logic;
     i_ready : in std_logic;
     o_data  : out std_logic_vector(DW - 1 downto 0));
end skidbuffer;

architecture skidbuffer of skidbuffer is

  -- -----------
  -- -- Types --
  -- -----------
  -- type din_t is array (natural range <>) of std_logic_vector(DATA_WIDTH - 1 downto 0);

  -------------
  -- Signals --
  -------------
  signal r_data : std_logic_vector(DW - 1 downto 0);

begin

  -------------------
  -- Port mappings --
  -------------------

  ------------------------------
  -- Asynchronous assignments --
  ------------------------------
  g_passthrough : if OPT_PASSTHROUGH generate
    o_ready <= i_ready;
    o_data  <= (others => '0') when i_valid = '0' and OPT_LOWPOWER else
               i_data;

    r_data <= (others => '0');

  end generate g_passthrough;

	-- We'll start with skid buffer itself
  g_not_passthrough : if not OPT_PASSTHROUGH generate
    signal r_valid   : std_logic := '0';
    signal o_ready_i : std_logic;
    signal o_valid_i : std_logic;
  begin

    o_ready <= o_ready_i;
    o_valid <= o_valid_i;

    process(i_clk)
    begin
      if rising_edge(i_clk) then
        if i_reset = '1' then
          r_valid <= '0';
        else
          if (i_valid = '1' and o_ready_i = '1') and (o_valid_i = '1' and i_ready = '0') then
            -- We have incoming data, but the output is stalled
            r_valid <= '1';
          elsif i_ready = '1' then
            r_valid <= '0';
          end if;
        end if;

      end if;
    end process;

    process(i_clk)
    begin
      if rising_edge(i_clk) then
        if (OPT_LOWPOWER and i_reset = '1') then
          r_data <= (others => '0');
        elsif OPT_LOWPOWER and (o_valid_i = '0' or i_ready = '1') then
          r_data <= (others => '0');
        elsif (not OPT_LOWPOWER or not OPT_OUTREG or i_valid = '1') and (o_ready_i = '1') then
          r_data <= i_data;
        end if;
      end if;
    end process;

    o_ready_i <= '1' when r_valid = '0' else '0';

		--
		-- And then move on to the output port
		--
    g_not_out_reg : if not OPT_OUTREG generate
      o_valid_i <= '1' when i_reset = '0' and (i_valid = '1' or r_valid = '1') else '0';

      process(r_valid, r_data, i_data, i_valid)
      begin
        if r_valid = '1' then
          o_data <= r_data;
        elsif not OPT_LOWPOWER or i_valid = '0' then
          o_data <= i_data;
        else
          o_data <= (others => '0');
        end if;
      end process;
    end generate g_not_out_reg;

    g_out_reg : if OPT_OUTREG generate
      process(i_clk)
      begin
        if rising_edge(i_clk) then
          if i_reset = '1' then
            o_valid_i <= '0';
          elsif o_valid_i = '0' or i_ready = '1' then
            o_valid_i <= i_valid or r_valid;
          end if;
        end if;
      end process;

      process(i_clk)
      begin
        if rising_edge(i_clk) then
          if OPT_LOWPOWER and i_reset = '1' then
            o_data <= (others => '0');
          elsif o_valid_i = '0' or i_ready = '1' then
            if r_valid = '1' then
              o_data <= r_data;
            elsif not OPT_LOWPOWER or i_valid = '1' then
              o_data <= i_data;
            else
              o_data <= (others => '0');
            end if;
          end if;
        end if;
      end process;

    end generate g_out_reg;


  end generate g_not_passthrough;

end skidbuffer;
