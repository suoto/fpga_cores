--
-- hdl_lib -- An HDL core library
--
-- Copyright 2014-2016 by Andre Souto (suoto)
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

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package common_pkg is

    -- Calculates the number of bits required to represent a given value
    function numbits (constant v : integer) return integer;
    -- Gray <-> Binary conversion
    function bin_to_gray (bin  : std_logic_vector) return std_logic_vector;
    function bin_to_gray (bin  : unsigned) return unsigned;
    function gray_to_bin (gray : std_logic_vector) return std_logic_vector;
    function gray_to_bin (gray : unsigned) return unsigned;

end common_pkg;

package body common_pkg is

    -- Calculates the number of bits required to represent a given value
    function numbits (
        constant v      : integer) return integer is
        variable result : integer;
    begin
        result := 1;
        while True loop
            if 2**(result + 1) > v then
                return result;
            end if;
            result := result + 1;
        end loop;
    end function numbits;

    -- Gray <-> Binary conversion
    function bin_to_gray (
                 bin  : std_logic_vector) return std_logic_vector is
        variable gray : std_logic_vector(bin'range);
    begin
        gray(gray'high) := bin(bin'high);
        for i in bin'high - 1 downto 0 loop
            gray(i) := bin(i + 1) xor bin(i);
        end loop;
        return gray;
    end function bin_to_gray;

    function gray_to_bin (
                 gray : std_logic_vector) return std_logic_vector is
        variable bin  : std_logic_vector(gray'range);
    begin
        bin(bin'high) := gray(gray'high);
        for i in gray'high - 1 downto 0 loop
            bin(i) := bin(i + 1) xor gray(i);
        end loop;
        return bin;
    end function gray_to_bin;

    function bin_to_gray (bin  : unsigned) return unsigned is
    begin
        return unsigned(bin_to_gray(std_logic_vector(bin)));
    end bin_to_gray;

    function gray_to_bin (gray : unsigned) return unsigned is
    begin
        return unsigned(gray_to_bin(std_logic_vector(gray)));
    end gray_to_bin;

end package body;
