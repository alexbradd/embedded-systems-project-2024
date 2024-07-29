#!/bin/bash

source $ROOT/.venv/bin/activate
source $ROOT/cva6/verif/setup-env.sh

python3 $ROOT/cva6/verif/sim/cva6.py \
  --target cv64a6_imafdc_sv39 \
  --iss=veri-testharness \
  --iss_yaml=$ROOT/cva6/verif/sim/cva6.yaml \
  --elf_tests=$LINUX_O \
  --issrun_opts="+time_out=4000000000 +debug_disable=1 +jtag_rbb_enable=1" \
  --isspostrun_opts="ffffffe0005e5cd4"

deactivate
