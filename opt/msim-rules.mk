
ROOT_DIR ?= .

FILES =

$(LIB): $(ROOT_DIR)/$(LIB)/_info $(call vhd2obj,$(SOURCE_LIST)) comp-lib

$(ROOT_DIR)/%/_info:
	if [ -f "$(ROOT_DIR)/modelsim.ini" ]; then \
		vlib $(ROOT_DIR)/$*; \
		vmap -modelsimini $(ROOT_DIR)/modelsim.ini $* $(ROOT_DIR)/$*; \
	else \
		vlib $(ROOT_DIR)/$*; \
		vmap $* $(ROOT_DIR)/$*; \
	fi

$(ROOT_DIR)/$(LIB)/%/_primary.dat: %.vhd
	$(eval FILES += $*.vhd)

comp-lib:
	@if [ "$(FILES)" != "" ]; then \
		echo vcom -$(VHDL_VERSION) $(VCOM_ARGS_G) $(VCOM_ARGS) -modelsimini $(ROOT_DIR)/modelsim.ini -work $(ROOT_DIR)/$(LIB) $(FILES); \
		vcom -$(VHDL_VERSION) $(VCOM_ARGS_G) $(VCOM_ARGS) -modelsimini $(ROOT_DIR)/modelsim.ini -work $(ROOT_DIR)/$(LIB) $(FILES); \
	fi

clean-lib:
	rm -rf $(ROOT_DIR)/$(LIB)/ modelsim.ini

