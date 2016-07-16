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
    use ieee.std_logic_arith.all;
    use ieee.std_logic_unsigned.all;
    use ieee.math_real.all;

package common_pkg is

    -- Calculates the number of bits required to represent a given value
    function numbits (constant v : integer) return integer;
    -- Gray <-> Binary conversion
    function bin_to_gray (bin  : std_logic_vector) return std_logic_vector;
    function gray_to_bin (gray : std_logic_vector) return std_logic_vector;

end common_pkg;

package body common_pkg is

    -- Calculates the number of bits required to represent a given value
    function numbits (
        constant v      : integer) return integer is
        variable result : integer;
    begin
        if v = 0 or v = 1 then
            result := 1;
        else
            result := integer(ceil(log(real(v))/log(2.0)));
        end if;
        return result;
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

end package body;
