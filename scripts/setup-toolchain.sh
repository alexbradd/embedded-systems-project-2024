#!/bin/bash

set -e

cd $ROOT/cva6/util/gcc-toolchain-builder/
NUM_JOBS=$NUM_JOBS bash get-toolchain.sh gcc-13.1.0-baremetal
NUM_JOBS=$NUM_JOBS bash build-toolchain.sh gcc-13.1.0-baremetal $RISCV
