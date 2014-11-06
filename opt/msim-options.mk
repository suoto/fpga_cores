
VHDL_VERSION ?= -93
VCOM_ARGS_G ?= -64 -explicit -O5
VSIM_ARGS_G ?= -novopt -64 -quiet

#vhd2obj = $(patsubst %.vhd,$(ROOT_DIR)/$(LIB)/%/$&.dat,$(1))
vhd2obj = $(patsubst %.vhd,$(ROOT_DIR)/$(LIB)/.db/%,$(1))
