# Vortex Tutorial - Remote Option

We suggest that you use ssh into a machine hosted by the CRNCH Rogues Gallery if you are not able to download and use the local VM Image. This option will be available until the end of the conference (November 1st)

## Selecting a username
Please use the [spreadsheet here](https://docs.google.com/spreadsheets/d/1ISum4aZnXu5L_aYllZsVUR3lIca7MH6kc9qXQHgfWWE/edit#gid=0) to reserve a username to use for the duration of the tutorial. The organizers will share a password with you for your particular username.

## Terminal Login
    ssh <username>@rg-login.crnch.gatech.edu
	
After logging into rg-login noded, run:

    ssh flubber1

## Vortex Setup

### Download Vortex codebase
    git clone --recursive https://github.com/vortexgpgpu/vortex.git

### Set up environment
    export VERILATOR_ROOT=/opt/verilator
    export GNU_RISCV_ROOT=/opt/riscv-gnu-toolchain
    export RISCV_TOOLCHAIN_PATH=$GNU_RISCV_ROOT
    export LLVM_VORTEX=/opt/llvm-vortex
    export LLVM_POCL=/opt/llvm-pocl
    export POCL_CC_PATH=/opt/pocl/compiler
    export POCL_RT_PATH=/opt/pocl/runtime
    export PATH=${VERILATOR_ROOT}/bin:${GNU_RISCV_ROOT}/bin/:$PATH
    export LD_LIBRARY_PATH=${GNU_RISCV_ROOT}:$LD_LIBRARY_PATH

### Build Vortex
    cd vortex
    make -s

### Quick demo running vecadd OpenCL kernel on 2 cores
    ./ci/blackbox.sh --cores=2 --app=vecadd
