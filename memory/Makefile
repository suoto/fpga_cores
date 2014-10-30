include ../opt/opt.mk

LIB = memory
ROOT_DIR ?= .
VCOM_ARGS := -2008
SOURCE_LIST += ram_inference.vhd

$(LIB): $(ROOT_DIR)/$(LIB)/_info $(call vhd2obj,$(SOURCE_LIST))

$(ROOT_DIR)/%/_info:
	vlib $(ROOT_DIR)/$*
	vmap -modelsimini $(ROOT_DIR)/modelsim.ini $* $(ROOT_DIR)/$*

$(ROOT_DIR)/$(LIB)/%/_primary.dat: $(SOURCE_LIST)
	vcom $(VCOM_ARGS_G) $(VCOM_ARGS) -modelsimini $(ROOT_DIR)/modelsim.ini -work $(ROOT_DIR)/$(LIB) $*.vhd

clean:
	rm -rf $(ROOT_DIR)/$(LIB)/ modelsim.ini
