library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use ieee.math_real.all;

package common_pkg is

    function numbits (v : integer) return integer;
    function bin_to_gray ( bin  : std_logic_vector) return std_logic_vector;
    function gray_to_bin ( gray : std_logic_vector) return std_logic_vector;
    function gray_inc    ( gray : std_logic_vector) return std_logic_vector;

end;

package body common_pkg is

    function numbits (v : positive) return positive is
            variable result : integer;
            variable base : positive := 2;
        begin
            if v = 0 or v = 1 then
                result := 1;
            else
                result := integer(ceil(log(real(v))/log(2.0)));
            end if;
            return result;
        end function numbits;

    function bin_to_gray ( bin : std_logic_vector) return std_logic_vector is
        variable gray : std_logic_vector(bin'range);
    begin
        gray(gray'high) := bin(bin'high);
        for i in bin'high - 1 downto 0 loop
            gray(i) := bin(i + 1) xor bin(i);
        end loop;
        return gray;
    end function bin_to_gray;

    function gray_to_bin ( gray : std_logic_vector) return std_logic_vector is
        variable bin : std_logic_vector(gray'range);
    begin
        bin(bin'high) := gray(gray'high);
        for i in gray'high - 1 downto 0 loop
            bin(i) := bin(i + 1) xor gray(i);
        end loop;
        return bin;
    end function gray_to_bin;

    function gray_inc ( gray : std_logic_vector) return std_logic_vector is
        variable bin : std_logic_vector(gray'range);
    begin
        bin := gray_to_bin(gray);
        bin := bin + 1;
        return bin_to_gray(bin);
    end function gray_inc;

end package body;
