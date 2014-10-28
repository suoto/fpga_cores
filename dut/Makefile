include ../opt/opt.mk

LIB = work
SOURCE_LIST += tb_pkg.vhd dut.vhd
VCOM_ARGS = -2008
#export ROOT_DIR=$(abspath ./)
export ROOT_DIR=../dut

all:
	cd ../common_lib/ && $(MAKE) $(MFLAGS)
	cd ../pck_fio_lib/ && $(MAKE) $(MFLAGS)
	$(MAKE) work/_info $(call vhd2obj,$(SOURCE_LIST))

%/_info:
	vlib $*
	vmap $* $*

$(ROOT_DIR)/$(LIB)/%/_primary.dat: %.vhd
	vcom $(VCOM_ARGS_G) $(VCOM_ARGS) -work $(ROOT_DIR)/$(LIB) $^

clean: $(wildcard */_info)
	rm -rf $(patsubst %/_info,%/,$^)
	rm -rf modelsim.ini *.wlf transcript
	cd ../common_lib/ && $(MAKE) clean
	cd ../pck_fio_lib/ && $(MAKE) clean

run: all
	vsim -64 -t 1ns -c -lib $(LIB) dut -do "run 1 ms; exit -f"

gui: all
	vsim -t 1ns -gui -lib $(LIB) dut -do "do wave.do; run 1 ms"

