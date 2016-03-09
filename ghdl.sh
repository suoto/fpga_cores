#!/usr/bin/env bash
set -x

WORKDIR=.build

LIBS=(
common_lib
memory
osvvm_lib
pck_fio_lib)


rm -rf $WORKDIR
mkdir -p $WORKDIR

for lib in ${LIBS[*]}; do
  mkdir -p "$WORKDIR/$lib"
  ghdl -i --ieee=synopsys --std=02 --work="$lib" --workdir="$WORKDIR/$lib" "$lib"/*.vhd
done

for lib in ${LIBS[*]}; do
  ghdl -a --ieee=synopsys --std=02 --work="$lib" --workdir="$WORKDIR/$lib" "$lib"/*.vhd
done

# mkdir -p .build/basic_library
# mkdir -p .build/another_library

# ghdl -i --work=another_library --workdir=.build/another_library another_library/*.vhd

# # ghdl -e --workdir=.build/basic_library very_common_pkg
# # ghdl -e --workdir=.build/basic_library package_with_constants
# # ghdl -e --workdir=.build/basic_library package_with_functions
# ghdl -a --ieee=synopsys --work=basic_library --workdir=.build/basic_library basic_library/clock_divider.vhd
# ghdl -e --ieee=synopsys --work=basic_library --workdir=.build/basic_library clock_divider

# # ghdl -m --workdir=.build/another_library foo

# # vhdl basic_library basic_library/very_common_pkg
# # vhdl basic_library basic_library/package_with_constants
# # vhdl basic_library basic_library/clock_divider
# # vhdl another_library another_library/foo.vhd  -2008
# # vhdl basic_library basic_library/package_with_functions.vhd 
