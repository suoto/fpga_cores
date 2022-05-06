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

---------------
-- Libraries --
---------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library ieee;
    use ieee.math_real.all;

package exp_golomb_pkg is

    -- We need to know how many bits we need to represent a given value, i.e., log2(d).
    -- Since the number of results are much smaller than the number of possible inputs,
    -- doing this calculation statically saves lots of resources at the expense of a
    -- longer code
    function bin_width (d : unsigned) return integer;

    function bin_width (d : unsigned) return unsigned;

    -- Overloaded bin_width to convert std_logic_vector to unsigned
    function bin_width (d : std_logic_vector) return integer;

    -- Overloaded bin_width to take std_logic_vector as input and output
    function bin_width (d : std_logic_vector) return unsigned;

    -- Calculates the number of bits to represent a given number
    function numbits (v : integer) return integer;

    -- 
    procedure runtime_check (
        constant data       : std_logic_vector;
        constant encoded    : std_logic_vector);

    procedure runtime_check (
        constant data       : unsigned;
        constant encoded    : unsigned);

    -- This should work for ModelSim, GHDL, Xilinx and Altera
    constant IS_SIMULATION : boolean :=
        False
        -- pragma translate_off
        -- synthesis translate_off
        or True
        -- pragma translate_on
        -- synthesis translate_on
        ;

end package;

package body exp_golomb_pkg is

    --
    function bin_width (d : unsigned) return integer is
        constant DATA_WIDTH : integer := d'length;
        variable result     : integer;
    begin

        if d = 0 or d = 1 then
            result := 1;
        else
            for i in 0 to DATA_WIDTH - 2 loop
                if d >= 2**i and d < 2**(i + 1) then
                    result := i + 1;
                end if;
            end loop;
        end if;

        return result;
    end function;

    --
    function bin_width (d : unsigned) return unsigned is
        constant DATA_WIDTH : integer := numbits(d'length);
        begin
            return to_unsigned(bin_width(d), DATA_WIDTH);
        end function bin_width;

    --
    function bin_width (d : std_logic_vector) return integer is
        begin
            return bin_width(unsigned(d));
        end function bin_width;

    --
    function bin_width (d : std_logic_vector) return unsigned is
        constant DATA_WIDTH : integer := numbits(d'length);
        begin
            return to_unsigned(bin_width(d), DATA_WIDTH);
        end function bin_width;

    --
    function numbits (v : integer) return integer is
        variable result : integer;
        begin
            if v = 0 or v = 1 then
                result := 1;
            else
                result := 0;
                while True loop
                    result := result + 1;
                    if v <= 2**result - 1 then
                        exit;
                    end if;
                end loop;
            end if;

            return result;
        end function numbits;

    --
    procedure runtime_check (
        constant data       : std_logic_vector;
        constant encoded    : std_logic_vector) is
        variable data_v     : integer;
        variable ref        : std_logic_vector(encoded'length - 1 downto 0);
        variable check      : boolean;
        variable ref_dwidth : integer;
        begin
            data_v := to_integer(unsigned(data)) - 1;
            ref    := (others => 'X');
            check  := True;
            case data_v is
                when 0 => ref(0 downto 0)       := "1";
                when 1 => ref(2 downto 0)       := "010";
                when 2 => ref(2 downto 0)       := "011";
                when 3 => ref(4 downto 0)       := "00100";
                when 4 => ref(4 downto 0)       := "00101";
                when 5 => ref(4 downto 0)       := "00110";
                when 6 => ref(4 downto 0)       := "00111";
                when 7 => ref(6 downto 0)       := "0001000";
                when 8 => ref(6 downto 0)       := "0001001";
                when 9 => ref(6 downto 0)       := "0001010";
                when 10 => ref(6 downto 0)      := "0001011";
                when 11 => ref(6 downto 0)      := "0001100";
                when 14 => ref(6 downto 0)      := "0001111";
                when 15 => ref(8 downto 0)      := "000010000";
                when 16 => ref(8 downto 0)      := "000010001";
                when 30 => ref(8 downto 0)      := "000011111";
                when 31 => ref(10 downto 0)     := "00000100000";
                when 32 => ref(10 downto 0)     := "00000100001";
                when 62 => ref(10 downto 0)     := "00000111111";
                when 63 => ref(12 downto 0)     := "0000001000000";
                when 64 => ref(12 downto 0)     := "0000001000001";
                when 126 => ref(12 downto 0)    := "0000001111111";
                when 127 => ref(14 downto 0)    := "000000010000000";
                when 128 => ref(14 downto 0)    := "000000010000001";
                when 254 => ref(14 downto 0)    := "000000011111111";
                when 255 => ref(16 downto 0)    := "00000000100000000";
                when 256 => ref(16 downto 0)    := "00000000100000001";
                when 510 => ref(16 downto 0)    := "00000000111111111";
                when 511 => ref(18 downto 0)    := "0000000001000000000";
                when 512 => ref(18 downto 0)    := "0000000001000000001";
                when 1022 => ref(18 downto 0)   := "0000000001111111111";
                when 1023 => ref(20 downto 0)   := "000000000010000000000";
                when 1024 => ref(20 downto 0)   := "000000000010000000001";
                when 2046 => ref(20 downto 0)   := "000000000011111111111";
                when 2047 => ref(22 downto 0)   := "00000000000100000000000";
                when 2048 => ref(22 downto 0)   := "00000000000100000000001";
                when 4094 => ref(22 downto 0)   := "00000000000111111111111";
                when 4095 => ref(24 downto 0)   := "0000000000001000000000000";
                when 4096 => ref(24 downto 0)   := "0000000000001000000000001";
                when 8190 => ref(24 downto 0)   := "0000000000001111111111111";
                when 8191 => ref(26 downto 0)   := "000000000000010000000000000";
                when 8192 => ref(26 downto 0)   := "000000000000010000000000001";
                when 16382 => ref(26 downto 0)  := "000000000000011111111111111";
                when 16383 => ref(28 downto 0)  := "00000000000000100000000000000";
                when 16384 => ref(28 downto 0)  := "00000000000000100000000000001";
                when 32766 => ref(28 downto 0)  := "00000000000000111111111111111";
                when 32767 => ref(30 downto 0)  := "0000000000000001000000000000000";
                when 32768 => ref(30 downto 0)  := "0000000000000001000000000000001";
                when 65534 => ref(30 downto 0)  := "0000000000000001111111111111111";
                when 65535 => ref(32 downto 0)  := "000000000000000010000000000000000";
                when 65536 => ref(32 downto 0)  := "000000000000000010000000000000001";
                when 131070 => ref(32 downto 0) := "000000000000000011111111111111111";
                when 131071 => ref(34 downto 0) := "00000000000000000100000000000000000";
                when 131072 => ref(34 downto 0) := "00000000000000000100000000000000001";
                when others => 
                    check := False;
                    null;
            end case;

            if check then
                -- Not every ref bits are valid, so find out which ones are
                for i in 0 to ref'length - 1 loop
                    if ref(i) = '0' or ref(i) = '1' then
                        ref_dwidth := i;
                    end if;
                end loop;

                assert encoded(ref_dwidth - 1 downto 0) = ref(ref_dwidth - 1 downto 0)
                    report "data = " & integer'image(to_integer(unsigned(data))) & ": " &
                           "got " & integer'image(to_integer(unsigned(encoded))) & " " &
                           "instead of " & integer'image(to_integer(unsigned(ref)));
            end if;
        end procedure;

    procedure runtime_check (
        constant data       : unsigned;
        constant encoded    : unsigned) is
    begin
        runtime_check(std_logic_vector(data), std_logic_vector(encoded));
    end procedure;

        
end package body;

