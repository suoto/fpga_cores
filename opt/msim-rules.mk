
ROOT_DIR ?= .

FILES =

vhd2obj = $(patsubst %.vhd,$(ROOT_DIR)/$(LIB)/.db/%,$(1))

$(LIB): $(ROOT_DIR)/$(LIB)/_info $(call vhd2obj,$(SOURCE_LIST)) comp-$(LIB)

$(ROOT_DIR)/%/_info:
	@mkdir -p $(ROOT_DIR)/libs
	@mkdir -p $(ROOT_DIR)/$(LIB)/.db
	@touch $(ROOT_DIR)/$(LIB)/_info

$(ROOT_DIR)/$(LIB)/.db/%: %.vhd
	$(eval FILES += $*.vhd)

comp-$(LIB):
	@if [ "$(FILES)" != "" ]; then \
		if [ "$(VHDL_VERSION)" = "-93" ]; then \
			echo ghdl -a $(GHDL_OPTIONS) --std=93c --ieee=synopsys --no-vital-checks --workdir=$(ROOT_DIR)/libs -P$(ROOT_DIR)/libs --work=$(LIB) $(FILES);\
			ghdl -a --std=93c --ieee=synopsys --no-vital-checks --workdir=$(ROOT_DIR)/libs -P$(ROOT_DIR)/libs --work=$(LIB) $(FILES);\
		elif [ "$(VHDL_VERSION)" = "-2008" ]; then \
			echo ghdl -a $(GHDL_OPTIONS) --std=02 --ieee=synopsys --workdir=$(ROOT_DIR)/libs -P$(ROOT_DIR)/libs --work=$(LIB) $(FILES);\
			ghdl -a --std=02 --ieee=synopsys --no-vital-checks --workdir=$(ROOT_DIR)/libs -P$(ROOT_DIR)/libs --work=$(LIB) $(FILES);\
		else \
			echo "================================" ; \
			echo "VHDL version? => $(VHDL_VERSION)" ; \
			echo "================================" ; \
		fi; \
		if [ "$$?" != 0 ]; then \
			exit 1;\
		fi; \
		touch $(patsubst %.vhd,$(ROOT_DIR)/$(LIB)/.db/%,$(FILES)) ;\
	fi
#		echo "# vcom $(VHDL_VERSION) $(VCOM_ARGS_G) -modelsimini $(ROOT_DIR)/modelsim.ini -work $(ROOT_DIR)/$(LIB) $(FILES)"; \
		vcom $(VHDL_VERSION) $(VCOM_ARGS_G) -modelsimini $(ROOT_DIR)/modelsim.ini -work $(ROOT_DIR)/$(LIB) $(FILES); \

clean-lib:
	rm -rf $(ROOT_DIR)/$(LIB)/ $(ROOT_DIR)/libs/ modelsim.ini

duh:
	@echo $(patsubst %.vhd,$(ROOT_DIR)/$(LIB)/.db/%.comp,$(SOURCE_LIST))
