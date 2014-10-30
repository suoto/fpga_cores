
VHDL_VERSION = 93
VCOM_ARGS_G = -64 -explicit -O5
VSIM_ARGS_G = -novopt

vhd2obj = $(patsubst %.vhd,$(ROOT_DIR)/$(LIB)/%/_primary.dat,$(1))
