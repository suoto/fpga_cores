

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

library pck_fio_lib;
    use pck_fio_lib.PCK_FIO.all;

package tb_pkg is

    type bfm_t is protected
        procedure write (a, v : integer);
        impure function read (p : integer) return integer;
    end protected;
end;

package body tb_pkg is

    type Item;
    type link is access Item; --pointer to item

    type Item is record
        data      : integer;
        next_item : link;
    end record;

--......
--variable StartOfList, Ptr : link;  --initialise to null
--.....
--ptr := new Item;
--ptr.data := 1982719;
--ptr.NextItem := StartOfList;  --link item into list
--StartOfList := ptr; 
--
--.......
--
----To delete the list
--while StartOfList /= null loop
--  ptr := StartOfList.NextItem;
--  DEALLOCATE(StartOfList);
--  StartOfList := ptr;
--end loop;


    type bfm_t is protected body

        variable ptr      : link;
        variable wr_ptr   : integer := 0;
        variable rd_ptr   : integer := 0;
        variable locked   : boolean := false;

        procedure write (a, v : integer ) is
                variable this_item : link;
                variable last_item : link;
                variable item_cnt  : integer;
            begin
                while locked loop
                    fprint("==== Caught locked! ====");
                end loop;
                this_item      := new Item;
                this_item.data := v;

                item_cnt := 0;
                last_item := ptr;

                if a = 0 then
                    fprint("Writing at addr 0\n");
                    ptr := this_item;
                else
                    item_cnt := item_cnt + 1;
                    for i in 1 to a - 1 loop
                        last_item := last_item.next_item;
                        item_cnt := item_cnt + 1;
                    end loop;
                    fprint("Writing at addr %d\n", fo(item_cnt));
                    last_item.next_item := this_item;
                end if;

        end procedure write;

        impure function read(p : integer) return integer is
                variable result : integer := 0;
                variable this_item : link;
                variable prev_item : link;
            begin
                fprint("==== p = %d =====\n", fo (p));
                while locked loop
                    fprint("==== Caught locked! ====");
                    null;
                end loop;
                this_item := ptr;
                result := this_item.data;
                ptr := this_item.next_item;
                DEALLOCATE(this_item);
                return result;
            end function read;
    end protected body;
end package body;
