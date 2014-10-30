include ../../opt/opt.mk

RUN_TIME ?= 250 ns

LIB = work
SOURCE_LIST += tb_pkg.vhd
SOURCE_LIST += dut.vhd
VCOM_ARGS = -2008
export ROOT_DIR=$(abspath ./)
#export ROOT_DIR=../dut


all:
	$(MAKE) work/_info
	cd ../../common_lib/ && $(MAKE) $(MFLAGS)
	cd ../../pck_fio_lib/ && $(MAKE) $(MFLAGS)
	cd ../../memory/ && $(MAKE) $(MFLAGS)
	$(MAKE) $(call vhd2obj,$(SOURCE_LIST))

%/_info:
	vlib $*
	vmap  $* $(ROOT_DIR)/$*

$(ROOT_DIR)/$(LIB)/%/_primary.dat: %.vhd
	vcom $(VCOM_ARGS_G) $(VCOM_ARGS) -modelsimini $(ROOT_DIR)/modelsim.ini -work $(ROOT_DIR)/$(LIB) $*.vhd

clean:
	rm -rf $(LIB)
	rm -rf modelsim.ini *.wlf transcript
	cd ../../common_lib/ && $(MAKE) clean
	cd ../../pck_fio_lib/ && $(MAKE) clean
	cd ../../memory/ && $(MAKE) clean

run: all
	vsim -64 -t 1ns -c $(VSIM_ARGS_G) -lib $(LIB) dut -do "run $(RUN_TIME); exit -f"

gui: all
	vsim -t 1ns -gui $(VSIM_ARGS_G) -lib $(LIB) dut -do "do wave.do; run $(RUN_TIME)"

