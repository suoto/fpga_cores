library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

use ieee.math_real.all;

package common_pkg is

    function numbits (v : integer) return integer;

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

end package body;
