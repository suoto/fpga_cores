#!/usr/bin/env bash
#
# FPGA core library
#
# Copyright 2019 by Andre Souto (suoto)
#
# This source describes Open Hardware and is licensed under the CERN-OHL-W v2
#
# You may redistribute and modify this documentation and make products using it
# under the terms of the CERN-OHL-W v2 (https:/cern.ch/cern-ohl).This
# documentation is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY,
# INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A
# PARTICULAR PURPOSE. Please see the CERN-OHL-W v2 for applicable conditions.
#
# Source location: https://github.com/suoto/fpga_cores
#
# As per CERN-OHL-W v2 section 4.1, should You produce hardware based on these
# sources, You must maintain the Source Location visible on the external case
# of the FPGA Cores or other product you make using this documentation.


set -e

PATH_TO_REPO=$(git rev-parse --show-toplevel)
CONTAINER="ghdl/synth:beta"

# This will be run inside the container
RUN_COMMAND="
set -e

PATH_TO_THIS_SCRIPT=\$(readlink -f \"\$(dirname \$0)\")

pushd \$PATH_TO_THIS_SCRIPT/..

addgroup $USER --gid $(id -g) > /dev/null 2>&1

adduser --disabled-password \
  --gid $(id -g)            \
  --uid $UID                \
  --home /home/$USER $USER > /dev/null 2>&1

# Run test with GHDL
su -l $USER -c \"                      \
  cd /project                       && \
  yosys -m ghdl misc/yosys/synth.ys $*\"
"

# Need to add some variables so that uploading coverage from witihin the
# container to codecov works
docker run                                                 \
  --rm                                                     \
  --mount type=bind,source="$PATH_TO_REPO",target=/project \
  --net=host                                               \
  --env="TERM"                                             \
  --env="DISPLAY"                                          \
  --volume="$HOME/.Xauthority:/root/.Xauthority:rw"        \
  $CONTAINER /bin/bash -c "$RUN_COMMAND"


