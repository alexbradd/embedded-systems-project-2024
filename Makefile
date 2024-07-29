mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
root := $(dir $(mkfile_path))

NUM_JOBS ?= 1

LINUX_O := $(root)/build/vmlinux.o

CVA6_TOOLS := $(root)/cva6/tools
RISCV      := $(CVA6_TOOLS)/toolchain
SPIKE      := $(CVA6_TOOLS)/spike
VERILATOR  := $(CVA6_TOOLS)/verilator

sim: $(RISCV) $(VERILATOR) $(SPIKE) $(LINUX_O) $(root)/.venv
	ROOT=$(root) RISCV=$(RISCV) LINUX_O=$(LINUX_O) bash $(root)/scripts/run-simulation.sh

$(RISCV): $(CVA6_TOOLS)
	@echo "#### Building RISCV compiler toolchain"
	@NUM_JOBS=$(NUM_JOBS) ROOT=$(root) RISCV=$(RISCV) bash $(root)/scripts/setup-toolchain.sh

$(SPIKE): $(CVA6_TOOLS) $(VERILATOR)
	@echo "#### Building SPIKE"
	@NUM_JOBS=$(NUM_JOBS) RISCV=$(RISCV) bash $(root)/cva6/verif/regress/install-spike.sh

$(VERILATOR): $(CVA6_TOOLS)
	@echo "#### Building Verilator"
	@NUM_JOBS=$(NUM_JOBS) RISCV=$(RISCV) VERILATOR_INSTALL_DIR=$(VERILATOR) \
					 bash $(root)/cva6/verif/regress/install-verilator.sh

$(LINUX_O): $(root)/cva6-sdk $(root)/build
	@echo "#### Building Linux image"
	cd $(root)/cva6-sdk && $(MAKE) -j$(NUM_JOBS) vmlinux
	cp $(root)/cva6-sdk/install64/vmlinux $(LINUX_O)

$(root)/.venv:
	@echo "#### Setting python venv"
	python3 -m venv $(root)/.venv
	ROOT=$(root) bash scripts/setup-venv.sh

$(root)/build $(CVA6_TOOLS):
	mkdir -p $@

clean-spike:
	rm -rf $(SPIKE) || true

clean-verilator:
	rm -rf $(VERILATOR) || true

clean-gcc:
	rm -rf $(RISCV) || true
	rm -rf $(root)/cva6/util/gcc-toolchain-builder/src || true

clean-linux:
	make -C $(root)/cva6-sdk clean
	rm -f $(LINUX_O) || true

clean-venv:
	rm -rf $(root)/.venv || true

clean: clean-spike clean-verilator clean-gcc clean-linux clean-venv
	RISCV=$(RISCV) make -C $(root)/cva6 clean

.PHONY: clean clean-spike clean-verilator clean-gcc clean-linux clean-venv sim

.NOTPARALLEL:
