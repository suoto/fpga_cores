

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.std_logic_arith.all;
    use ieee.std_logic_unsigned.all;

library pck_fio_lib;
    use pck_fio_lib.PCK_FIO.all;

package ram_model_pkg is
    type ram_bfm_type is protected
        procedure write (a, d : std_logic_vector );
        procedure write (a, d : integer);
        impure function read (a : integer) return integer;
    end protected;
end package ram_model_pkg;

package body ram_model_pkg is

    type memory_position;
    type ptr_t is access memory_position; --pointer to item

    type memory_position is record
        addr    : integer; 
        data    : integer; 
        next_p  : ptr_t;
    end record;

    type ram_bfm_type is protected body

        variable ptr        : ptr_t;
        variable wr_ptr     : integer := 0;
        variable rd_ptr     : integer := 0;
        variable locked     : boolean := false;
        variable ADDR_WIDTH : integer := 16;
        variable DATA_WIDTH : integer := 16;

        procedure write (a, d : integer ) is
            begin
                write( conv_std_logic_vector(a, ADDR_WIDTH),
                    conv_std_logic_vector(d, DATA_WIDTH));
            end procedure write;

        procedure write (a, d : std_logic_vector ) is
            variable this_item : ptr_t;
            variable last_item : ptr_t;
            variable a_i       : integer;
            variable item_cnt  : integer := 0;
            begin
                a_i := conv_integer(a);
                this_item      := new memory_position;
                this_item.addr := conv_integer(a);
                this_item.data := conv_integer(d);

                fprint("Write: (%r) <== %r\n", fo(a), fo(d));

                if ptr = null then
                    ptr := this_item;
                    fprint("Assigning ptr\n");
                    else
                    last_item := ptr;
                    while last_item.next_p /= null loop
                        if last_item.addr = a_i then
                            last_item.data := conv_integer(d);
                            exit;
                        end if;
                        last_item := last_item.next_p;
                        item_cnt := item_cnt + 1;
                    end loop;
                    if last_item.addr /= a_i then
                        fprint("Item cnt: %d\n", fo(item_cnt));
                        last_item.next_p := this_item;
                    end if;
                end if;
            end procedure write;

        impure function read(a : integer) return integer is
            variable result : integer := 0;
            variable a_i    : integer := a;

            variable this_item : ptr_t;
            variable prev_item : ptr_t;
            begin
                this_item := ptr;
                while this_item.addr /= a_i loop
                    if this_item.next_p = null then
                        result := -1;
                        exit;
                    end if;
                    this_item := this_item.next_p;
                end loop;
                if this_item.next_p /= null then
                    result := this_item.data;
                end if;
--                ptr := this_item.next_p;
--                DEALLOCATE(this_item);

                fprint("Read: %r => %r\n",
                    fo(conv_std_logic_vector(a_i, ADDR_WIDTH)),
                    fo(conv_std_logic_vector(result, DATA_WIDTH)));
                return result;
            end function read;
    end protected body;
end package body;
