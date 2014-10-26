
include ../pck_fio_lib/Makefile

LIB = work
SOURCE_LIST += tb_pkg.vhd dut.vhd

#pathsearch = $(firstword $(wildcard $(addsuffix /$(1),$(subst :, ,$(PATH)))))
vhd2obj = $(patsubst %.vhd,$(LIB)/%/_primary.dat,$(1))

$(LIB): pck_fio_lib $(LIB)/_info $(call vhd2obj,$(SOURCE_LIST))

%/_info:
	vlib $*
	vmap $* $*

$(LIB)/%/_primary.dat: %.vhd
	vcom -2008 -explicit -64 -work $(LIB) $*.vhd

run: $(LIB)
	vsim -64 -t 1ns -c -lib $(LIB) dut -do "run 1 ms; exit -f" -memprof

gui: $(LIB)
	vsim -t 1ns -lib $(LIB) dut -do "run 1 ms" -memprof

clean: $(wildcard */_info)
	rm -rf $(patsubst %/_info,%/,$^)
#	rm -rf $(LIB)


