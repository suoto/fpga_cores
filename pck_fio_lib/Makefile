

PCK_FIO_LIB = pck_fio_lib

$(PCK_FIO_LIB)_SOURCE_LIST += ../pck_fio_lib/pck_fio.vhd

VCOM_ARGS =-93 -explicit

#pathsearch = $(firstword $(wildcard $(addsuffix /$(1),$(subst :, ,$(PATH)))))
vhd2obj = $(patsubst %.vhd,$(PCK_FIO_LIB)/%/_primary.dat,$(1))

$(PCK_FIO_LIB): $(PCK_FIO_LIB)/_info $(call vhd2obj,$($(PCK_FIO_LIB)_SOURCE_LIST))

%/_info:
	vlib $*
	vmap $* $*

$(PCK_FIO_LIB)/%/_primary.dat: %.vhd
	vcom $(VCOM_ARGS) -work $(PCK_FIO_LIB) $*.vhd


