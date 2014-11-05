

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library pck_fio_lib;
    use pck_fio_lib.PCK_FIO.all;

package fifo_bfm_pkg is

    type fifo_bfm_type is protected
        procedure write (d : std_logic_vector );
        procedure write (d : integer);
        impure function read return std_logic_vector;
        procedure free;
        impure function is_empty return boolean;
    end protected;
end package fifo_bfm_pkg;

package body fifo_bfm_pkg is

    type memory_position;
    type ptr_t is access memory_position; --pointer to item

    type memory_position is record
        data    : std_logic_vector(15 downto 0); 
        next_p  : ptr_t;
    end record;

    type fifo_bfm_type is protected body

        variable ptr        : ptr_t;
        variable DATA_WIDTH : integer := 16;
        variable fifo_empty : boolean := true;

        procedure write (d : integer ) is
            begin
                write(conv_std_logic_vector(d, DATA_WIDTH));
               end procedure write;

        procedure write (d : std_logic_vector ) is
                variable this_item : ptr_t;
                variable last_item : ptr_t;
                variable item_cnt  : integer := 0;
            begin
                this_item      := new memory_position;
                this_item.data := d;

                if ptr = null then
                    ptr := this_item;
                else
                    last_item := ptr;
                    while last_item.next_p /= null loop
                        last_item := last_item.next_p;
                        item_cnt := item_cnt + 1;
                    end loop;
                    last_item.next_p := this_item;
                    fifo_empty := false;
                end if;
        end procedure write;

        impure function read return std_logic_vector is
                variable result : std_logic_vector(DATA_WIDTH - 1 downto 0);
                variable this_item : ptr_t;
            begin
                this_item := ptr;
                assert this_item /= null
                    report "Fifo is empty"
                    severity failure;
                if this_item.next_p = null then
                    fifo_empty := true;
                end if;
                result := this_item.data;

                -- TODO: check how to correctly deallocate unused positions of memory
                ptr := new memory_position;
                ptr := this_item.next_p;
                deallocate(this_item);
                return result;
            end function read;

        impure function is_empty return boolean is
            begin
                return fifo_empty;
            end function is_empty;
        
        procedure free is
            begin
                deallocate(ptr);
            end procedure free;
    end protected body;
end package body;
