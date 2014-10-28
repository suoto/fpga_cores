
VCOM_ARGS_G = -64 -explicit

vhd2obj = $(patsubst %.vhd,$(ROOT_DIR)/$(LIB)/%/_primary.dat,$(1))
