---------------
-- Libraries --
---------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use std.textio.all;
use ieee.std_logic_textio.all;

------------------------
-- Entity declaration --
------------------------
entity file_dumper is
    generic (
        FILENAME   : string := "output.bin";
        DATA_WIDTH : integer := 32
    );
    port (
        -- Usual ports
        clk     : in  std_logic;
        clken   : in  std_logic;
        rst     : in  std_logic;

        -- Data input
        tdata   : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        tvalid  : in  std_logic;
        tready  : in  std_logic
    );
end file_dumper;

architecture file_dumper of file_dumper is

    -----------
    -- Types --
    -----------
    type int_file is file of integer;

begin

    ---------------
    -- Processes --
    ---------------
    process
        file dump_file : int_file;
    begin
        file_open(dump_file, FILENAME, write_mode);
        wait until rst = '0';
        while True loop
            wait until clk'event and clk = '1' and clken = '1';
            if tvalid = '1' and tready = '1' then
                write(dump_file, to_integer(unsigned(tdata)));
            end if;
        end loop;
    end process;


end file_dumper;


