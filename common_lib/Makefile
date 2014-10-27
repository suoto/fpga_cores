

COMMON_LIB = common_lib

$(COMMON_LIB)_SOURCE_LIST += ../$(COMMON_LIB)/common_pkg.vhd
$(COMMON_LIB)_SOURCE_LIST += ../$(COMMON_LIB)/sr_delay.vhd
$(COMMON_LIB)_SOURCE_LIST += ../$(COMMON_LIB)/synchronizer.vhd
$(COMMON_LIB)_SOURCE_LIST += ../$(COMMON_LIB)/edge_detector.vhd

$(COMMON_LIB)_VCOM_ARGS =-2008 -explicit

#pathsearch = $(firstword $(wildcard $(addsuffix /$(1),$(subst :, ,$(PATH)))))
vhd2obj = $(patsubst %.vhd,$(COMMON_LIB)/%/_primary.dat,$(1))

$(COMMON_LIB): $(COMMON_LIB)/_info $(call vhd2obj,$($(COMMON_LIB)_SOURCE_LIST))

%/_info:
	vlib $*
	vmap $* $*

$(COMMON_LIB)/%/_primary.dat: %.vhd
	vcom $($(COMMON_LIB)_VCOM_ARGS) -work $(COMMON_LIB) $*.vhd


