include ../opt/opt.mk

LIB = common_lib
ROOT_DIR ?= .
VCOM_ARGS := -2008
SOURCE_LIST += common_pkg.vhd
SOURCE_LIST += sr_delay.vhd
SOURCE_LIST += synchronizer.vhd
SOURCE_LIST += edge_detector.vhd

$(LIB): $(ROOT_DIR)/$(LIB)/_info $(call vhd2obj,$(SOURCE_LIST))

$(ROOT_DIR)/%/_info:
	vlib $(ROOT_DIR)/$*
	vmap $* $(ROOT_DIR)/$*

$(ROOT_DIR)/$(LIB)/%/_primary.dat: $(addprefix $(ROOT_DIR)/../$(LIB)/,$(SOURCE_LIST))
	vcom $(VCOM_ARGS_G) $(VCOM_ARGS) -work $(ROOT_DIR)/$(LIB) $*.vhd

clean:
	rm -rf $(ROOT_DIR)/$(LIB)/ modelsim.ini
