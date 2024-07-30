#!/bin/bash

if ! [ -n "$RISCV" ]; then
  echo "Error: RISCV variable undefined"
  return
fi

# I stg this scripts are borken and do not work unless I do this. I am so done
# with this
cd $ROOT/cva6
source ./verif/regress/install-verilator.sh
source ./verif/regress/install-spike.sh
