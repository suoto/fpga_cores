
ROOT_DIR ?= .

FILES =

$(LIB): $(ROOT_DIR)/$(LIB)/_info $(call vhd2obj,$(SOURCE_LIST)) comp-$(LIB)

$(ROOT_DIR)/%/_info:
	@if [ -f "$(ROOT_DIR)/modelsim.ini" ]; then \
		echo "# vlib $(ROOT_DIR)/$*"; \
		vlib $(ROOT_DIR)/$*; \
		echo "# vmap -modelsimini $(ROOT_DIR)/modelsim.ini $* $(ROOT_DIR)/$*"; \
		vmap -modelsimini $(ROOT_DIR)/modelsim.ini $* $(ROOT_DIR)/$*; \
	else \
		echo "# vlib $(ROOT_DIR)/$*"; \
		vlib $(ROOT_DIR)/$*; \
		echo "# vmap $* $(ROOT_DIR)/$*"; \
		vmap $* $(ROOT_DIR)/$*; \
	fi
	@mkdir -p $(ROOT_DIR)/$(LIB)/.db

$(ROOT_DIR)/$(LIB)/.db/%: %.vhd
	$(eval FILES += $*.vhd)

comp-$(LIB):
	@if [ "$(FILES)" != "" ]; then \
		echo "# vcom $(VHDL_VERSION) $(VCOM_ARGS_G) -modelsimini $(ROOT_DIR)/modelsim.ini -work $(ROOT_DIR)/$(LIB) $(FILES)"; \
		vcom $(VHDL_VERSION) $(VCOM_ARGS_G) -modelsimini $(ROOT_DIR)/modelsim.ini -work $(ROOT_DIR)/$(LIB) $(FILES); \
		if [ "$$?" != 0 ]; then \
			exit 1;\
			fi; \
		touch $(patsubst %.vhd,$(ROOT_DIR)/$(LIB)/.db/%,$(FILES)) ;\
	fi

clean-lib:
	rm -rf $(ROOT_DIR)/$(LIB)/ modelsim.ini

duh:
	@echo $(patsubst %.vhd,$(ROOT_DIR)/$(LIB)/.db/%.comp,$(SOURCE_LIST))
