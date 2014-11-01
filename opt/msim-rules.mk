
ROOT_DIR ?= .

$(LIB): $(ROOT_DIR)/$(LIB)/_info $(call vhd2obj,$(SOURCE_LIST))

$(ROOT_DIR)/%/_info:
	if [ -f "$(ROOT_DIR)/modelsim.ini" ]; then \
		vlib $(ROOT_DIR)/$*; \
		vmap -modelsimini $(ROOT_DIR)/modelsim.ini $* $(ROOT_DIR)/$*; \
	else \
		vlib $(ROOT_DIR)/$*; \
		vmap $* $(ROOT_DIR)/$*; \
	fi

$(ROOT_DIR)/$(LIB)/%/_primary.dat: %.vhd
	vcom -$(VHDL_VERSION) $(VCOM_ARGS_G) $(VCOM_ARGS) -modelsimini $(ROOT_DIR)/modelsim.ini -work $(ROOT_DIR)/$(LIB) $*.vhd

clean-lib:
	rm -rf $(ROOT_DIR)/$(LIB)/ modelsim.ini

