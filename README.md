# Embedded Systems final project (a.y. 2023/2024)

Final project for the Embedded Systems course (a.y. 2023/2024) at Politecnico di
Milano.

Project objectives:

- Instantiate [CVA6](https://github.com/openhwgroup/cva6) cores (formerly Ariane)
- Port Linux to it to execute C applications.

## Setup

First clone this repository making sure to initialize all git submodules:

```sh
git clone --recurse-submodules https://github.com/alexbradd/embedded-systems-project-2024
# Or first clone normally and then run:
# git submodule update --init --recursive
```

Requirements:

- gcc >= 13
- For compiling all necessary tools (assuming Ubuntu-based distro):

  ```sh
  sudo apt-get install make autoconf automake autotools-dev curl libmpc-dev libmpfr-dev libgmp-dev libusb-1.0-0-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev device-tree-compiler pkg-config libexpat-dev libzstd-dev
  ```

- Python 3 with venvs
- OpenOCD

To speedup compilation, one can define the `NUM_JOBS` variable to define the
number of jobs to pass to inner `make` instances

## Synthesizing with Vivado

An instance of a CVA6 core is provided with the Vivado project inside
`cva6_instance`: simply open it with Vivado (tested with Vivado 2023.2) and run
the synthesis.

## Simulating

To run a simulation, execute

```sh
make sim
```

This will build all prerequisites and then start a simulation with a very large
timeout. To interact with this simulation, in another terminal, run:

```sh
openocd -f sim.cfg -c "remote_bitbang host localhost" -c "remote_bitbang port <PORT>"
```

Where `<PORT>` is the port number displayed in the simulation log file. We can
read it simply in another terminal as such:

```sh
cat ./cva6/verif/sim/out_YYYY-MM-DD/veri-testharness_sim/vmlinux.cv64a6_imafdc_sv39.log.iss

# It should contain something like this:
### ....make mumbo jumbo
### make[1]: Leaving directory '/home/bred/projects/cva6'
### <PROJECT ROOT>/cva6//work-ver/Variane_testharness ....
### This emulator compiled with JTAG Remote Bitbang client. To enable, use +jtag_rbb_enable=1.
### Listening on port 34579
### Attempting to accept client socket
```

