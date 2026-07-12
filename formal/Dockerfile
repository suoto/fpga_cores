#
# FPGA core library
#
# Copyright 2016-2022 by Andre Souto (suoto)
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

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y curl xz-utils libgomp1 && rm -rf /var/lib/apt/lists/*
RUN curl -L -o /tmp/oss.tgz \
      https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2026-07-11/oss-cad-suite-linux-arm64-20260711.tgz \
 && tar -xzf /tmp/oss.tgz -C /opt && rm /tmp/oss.tgz
ENV PATH="/opt/oss-cad-suite/bin:${PATH}"
WORKDIR /project
