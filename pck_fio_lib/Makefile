include ../opt/opt.mk

LIB = pck_fio_lib
ROOT_DIR ?= ./
VCOM_ARGS :=-93
SOURCE_LIST += pck_fio.vhd

$(LIB): $(ROOT_DIR)/$(LIB)/_info $(call vhd2obj,$(SOURCE_LIST))

$(ROOT_DIR)/%/_info:
	vlib $(ROOT_DIR)/$*
	vmap $* $(ROOT_DIR)/$*

$(ROOT_DIR)/$(LIB)/%/_primary.dat:
	vcom $(VCOM_ARGS_G) $(VCOM_ARGS) -work $(ROOT_DIR)/$(LIB) $*.vhd

clean:
	rm -rf $(ROOT_DIR)/$(LIB)/ modelsim.ini

