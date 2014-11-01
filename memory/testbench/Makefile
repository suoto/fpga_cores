include ../../opt/opt.mk

RUN_TIME ?= 1 us

LIB = work
SOURCE_LIST += ram_model_pkg.vhd
SOURCE_LIST += dut.vhd
export ROOT_DIR=$(abspath ./)
VHDL_VERSION := 2008
#export ROOT_DIR=../dut


all:
	$(MAKE) work/_info
	cd ../../common_lib/ && $(MAKE) $(MFLAGS)
	cd ../../pck_fio_lib/ && $(MAKE) $(MFLAGS)
	cd ../../memory/ && $(MAKE) $(MFLAGS)
	$(MAKE) $(call vhd2obj,$(SOURCE_LIST))

include ../../opt/msim-rules.mk

clean: clean-lib
	rm -rf *.wlf transcript
	cd ../../common_lib/ && $(MAKE) clean-lib
	cd ../../pck_fio_lib/ && $(MAKE) clean-lib
	cd ../../memory/ && $(MAKE) clean-lib

run: all
	vsim -64 -t 1ns -c $(VSIM_ARGS_G) -lib $(LIB) dut -do "run $(RUN_TIME); exit -f"

gui: all
	vsim -t 1ns -gui $(VSIM_ARGS_G) -lib $(LIB) dut -do "do wave.do; run $(RUN_TIME)"

