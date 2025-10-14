# Apptainer Build Process

Prerequisite: Install `apptainer` package on your machine by following [INSTALL.md](./INSTALL.md)


# Clone Vortex repo

Create tools directory for mounting vortex-toolchains onto the apptainer
```
$   mkdir -p tools
```

```
$	git clone --depth=1 --recursive https://github.com/vortexgpgpu/vortex.git
```

Go to `apptainer` directory and build the vortex apptainer

```
$   ls
    tools  vortex

$   cd vortex/miscs/apptainer

$  apptainer build --no-https vortex.sif vortex.def

```

To start the apptainer,
```
apptainer shell --fakeroot --cleanenv --writable-tmpfs  --bind ../../../vortex:/home/vortex --bind ../../../tools:/home/tools vortex.sif
```


# Vortex Simulation inside Apptainer

Go to the bind of vortex repo,
```
Apptainer> cd /home/vortex
Apptainer> ./ci/install_dependencies.sh
Apptainer> mkdir build
Apptainer> cd build
Apptainer> ../configure --xlen=32 --tooldir=$HOME/tools


Skip the below 3 steps, if toolchains are already present in the $HOME/tools; (These steps are compulsory while getting the setup ready for the first time)
Apptainer> sed -i 's/\btar /tar --no-same-owner /g' ci/toolchain_install.sh
Apptainer> ./ci/toolchain_install.sh --all
Apptainer> sed -i 's/\btar --no-same-owner /tar /g' ci/toolchain_install.sh

Apptainer> ls $HOME/tools/
libc32  libc64  libcrt32  libcrt64  llvm-vortex  pocl  riscv32-gnu-toolchain  riscv64-gnu-toolchain  sv2v  verilator  yosys

Apptainer> source ./ci/toolchain_env.sh
Apptainer> verilator --version
```


### Running SIMX, RTLSIM and XRTSIM
```
Compile the Vortex codebase
Apptainer> make -s

Run the programs by specifying the appropriate driver as shown below:

SIMX
Apptainer> ./ci/blackbox.sh --cores=2 --app=demo --driver=simx

RTLSIM
Apptainer> ./ci/blackbox.sh --cores=2 --app=demo --driver=rtlsim

XRTSIM
Apptainer> ./ci/blackbox.sh --cores=2 --app=demo --driver=xrt


Apptainer> make -C runtime/ clean
```
