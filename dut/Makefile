include ../opt/opt.mk

LIB = work
SOURCE_LIST += tb_pkg.vhd dut.vhd
ROOT_DIR = ./

all:
	export ROOT_DIR=$(abspath $(ROOT_DIR)) && cd ../common_lib/ && $(MAKE)
	export ROOT_DIR=$(abspath $(ROOT_DIR)) && cd ../pck_fio_lib/ && $(MAKE)
	$(MAKE) work/_info $(call vhd2obj,$(SOURCE_LIST))

%/_info:
	vlib $*
	vmap $* $*

$(LIB)/%/_primary.dat: %.vhd
	vcom -64 -2008 -explicit -64 -work $(LIB) $*.vhd

clean: $(wildcard */_info)
	rm -rf $(patsubst %/_info,%/,$^)
	rm -rf modelsim.ini *.wlf transcript
	export ROOT_DIR=$(abspath $(ROOT_DIR)) && cd ../common_lib/ && $(MAKE) clean
	export ROOT_DIR=$(abspath $(ROOT_DIR)) && cd ../pck_fio_lib/ && $(MAKE) clean

run: all
	vsim -64 -t 1ns -c -lib $(LIB) dut -do "run 1 ms; exit -f"

gui: $(LIB)
	vsim -t 1ns -lib $(LIB) dut -do "do wave.do; run 1 ms"

