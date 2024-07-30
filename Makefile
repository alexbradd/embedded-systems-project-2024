mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
root := $(dir $(mkfile_path))

NUM_JOBS ?= 1

LINUX_O := $(root)/build/vmlinux.o

CVA6_TOOLS := $(root)/cva6/tools
RISCV      := $(CVA6_TOOLS)/toolchain
SPIKE      := $(CVA6_TOOLS)/spike
VERILATOR  := $(CVA6_TOOLS)/verilator

tools: | $(RISCV) $(VERILATOR) $(LINUX_O) $(root)/.venv

sim: | tools
	ROOT=$(root) RISCV=$(RISCV) LINUX_O=$(LINUX_O) bash $(root)/scripts/run-simulation.sh

$(RISCV): | $(CVA6_TOOLS)
	@echo "#### Building RISCV compiler toolchain"
	@NUM_JOBS=$(NUM_JOBS) ROOT=$(root) RISCV=$(RISCV) bash $(root)/scripts/setup-toolchain.sh

$(VERILATOR): | $(CVA6_TOOLS)
	@echo "#### Building Verilator and SPIKE"
	NUM_JOBS=$(NUM_JOBS) RISCV=$(RISCV) ROOT=$(root) VERILATOR_INSTALL_DIR=$(VERILATOR) \
					 bash $(root)/scripts/setup-spike-verilator.sh

$(LINUX_O): | $(root)/cva6-sdk $(root)/build
	@echo "#### Building Linux image"
	cd $(root)/cva6-sdk && $(MAKE) -j$(NUM_JOBS) vmlinux
	cp $(root)/cva6-sdk/install64/vmlinux $(LINUX_O)

$(root)/.venv:
	@echo "#### Setting python venv"
	python3 -m venv $(root)/.venv
	ROOT=$(root) bash $(root)/scripts/setup-venv.sh

$(root)/build $(CVA6_TOOLS):
	mkdir -p $@

clean-spike-verilator:
	rm -rf $(SPIKE) || true
	rm -rf $(VERILATOR) || true

clean-gcc:
	rm -rf $(RISCV) || true
	rm -rf $(root)/cva6/util/gcc-toolchain-builder/src || true

clean-venv:
	rm -rf $(root)/.venv || true

clean-cva6: clean-spike-verilator clean-gcc clean-venv
	RISCV=$(RISCV) make -C $(root)/cva6 clean

clean-linux:
	make -C $(root)/cva6-sdk clean
	rm -f $(LINUX_O) || true

clean: clean-cva6 clean-linux

.PHONY: sim tools clean-spike-verilator clean-gcc clean-venv clean-cva6 clean-linux clean

.NOTPARALLEL:
