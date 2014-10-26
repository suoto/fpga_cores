--------------------------------------------------------
-- Simple Microprocessor Design 
--
-- Microprocessor composed of
-- Ctrl_Unit, Data_Path and Memory
-- structural modeling
-- microprocessor.vhd
--------------------------------------------------------

library	ieee;
    use ieee.std_logic_1164.all;  
    use ieee.std_logic_arith.all;			   

library work;
    use work.tb_pkg.all;

library pck_fio_lib;
    use pck_fio_lib.PCK_FIO.all;

entity dut is
end dut;

architecture dut of dut is

    shared variable bfm : bfm_t;

begin

    process
        variable wr_addr : integer;
        variable wr_data : integer;
    begin
        for i in 0 to 999 loop
            wr_addr := i;
            wr_data := i + 10;
            fprint("Writing %d at %d\n", fo(wr_data), fo(wr_addr));
            bfm.write(wr_addr, wr_data);
        end loop;
        for i in 0 to 999 loop
--            wr_data := bfm.read(i);
            fprint("Data read: %d\n", fo(bfm.read(i)));
        end loop;
        wait;
    end process;

end dut;

