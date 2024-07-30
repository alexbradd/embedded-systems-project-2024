#!/bin/bash

set -e

# For some reason, the script is sensible to local changes (especially if unset),
# so to be sure set it to C
export LC_ALL=C.utf-8

source $ROOT/.venv/bin/activate

cd $ROOT/cva6/verif/sim
source setup-env.sh

python3 cva6.py \
  --target cv64a6_imafdc_sv39 \
  --iss=veri-testharness \
  --iss_yaml=cva6.yaml \
  --elf_tests=$LINUX_O \
  --issrun_opts="+time_out=4000000000 +debug_disable=1 +jtag_rbb_enable=1" \
  --isspostrun_opts="ffffffe0005e5cd4"

deactivate
