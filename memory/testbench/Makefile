include ../../opt/msim-options.mk

RUN_TIME ?= 50 us

LIB = work
SOURCE_LIST += ram_model_pkg.vhd
SOURCE_LIST += fifo_bfm_pkg.vhd
SOURCE_LIST += async_fifo_tb.vhd
export ROOT_DIR=$(abspath ./)
VHDL_VERSION := -2008

all: $(ROOT_DIR)/work/_info .deps work

@cover:
	$(eval export VCOM_ARGS_G+=-coversub +cover=sbced)
	$(eval export VSIM_ARGS_G+=-assertcover -coverage)

.deps:
	cd $(ROOT_DIR)/../../common_lib/ && $(MAKE) $(MFLAGS)
	cd $(ROOT_DIR)/../../pck_fio_lib/ && $(MAKE) $(MFLAGS)
	cd $(ROOT_DIR)/../../memory/ && $(MAKE) $(MFLAGS)
	cd $(ROOT_DIR)/../../osvvm_lib/ && $(MAKE) $(MFLAGS)

include ../../opt/msim-rules.mk

clean: clean-lib
	rm -rf *.wlf transcript modelsim.ini
	cd ../../common_lib/ && $(MAKE) clean-lib
	cd ../../pck_fio_lib/ && $(MAKE) clean-lib
	cd ../../memory/ && $(MAKE) clean-lib
	cd ../../osvvm_lib/ && $(MAKE) clean-lib

run_async_fifo_tb: all
	$(MAKE) .run $(MFLAGS) TOP=async_fifo_tb

gui_async_fifo_tb: all
	$(MAKE) .gui $(MFLAGS) TOP=async_fifo_tb

.run:
	vsim -64 -t 1ns -c $(VSIM_ARGS_G) -lib $(LIB) $(TOP) \
		-do "run $(RUN_TIME); exit -f"

.gui:
	vsim -t 1ns -gui $(VSIM_ARGS_G) -lib $(LIB) $(TOP) \
		-do "do wave.do; \
		run $(RUN_TIME); \
		wave zoom full"



