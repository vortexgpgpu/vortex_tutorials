# Vortex Tutorial - Remote Option

We suggest that you use a remote server hosted by the [CRNCH Rogues Gallery](https://crnch-rg.cc.gatech.edu/). This option will be available until the end of the conference (October 22nd)

## Register for access
Please use the [form to submit your Github ID](https://forms.office.com/r/CynuGzyeDD) to reserve a slot to use for the duration of the tutorial.

## Login
Login to `crush.crnch.gatech.edu/jupyter` using your Github account.

 | **Note:** Participants have to agree / authorize to join the "gt-crnch-rg" team to get access. We do not get the password; This is just the authentication from GitHub that the user is a valid user.

Then, click "Start My Server".

Once there, open the terminal application and follow below steps
```
$ whoami
crunchjupyter

$ pwd
/tmp
```

##  Vortex Simulation

### Clone Vortex
```
$	git clone --depth=1 --recursive https://github.com/vortexgpgpu/vortex.git

```

### Start Apptainer

Go to `apptainer` directory and start the vortex apptainer using the command below:
The command 
* uses the pre-built apptainer image and 
* mounts the vortex repo and vortex_toolchain paths onto the apptainer

```
$   cd vortex/miscs/apptainer
$   apptainer shell --fakeroot --cleanenv --writable-tmpfs \
    --bind ../../../vortex:/home/vortex \
    --bind /projects/tools/x86_64/common-tools/vortex-tools:/home/tools \
    /projects/tools/x86_64/containers/vortex_micro25.sif
```

### Vortex Build and Simulation inside Apptainer

Go to the bind of vortex repo,
```
Apptainer> cd /home/vortex
Apptainer> ./ci/install_dependencies.sh
Apptainer> mkdir build
Apptainer> cd build
Apptainer> ../configure --xlen=32 --tooldir=$HOME/tools

Apptainer> ls $HOME/tools/
libc32  libc64  libcrt32  libcrt64  llvm-vortex  pocl  riscv32-gnu-toolchain  riscv64-gnu-toolchain  sv2v  verilator  yosys

Apptainer> source ./ci/toolchain_env.sh
Apptainer> verilator --version
```

#### Compilation
```
Apptainer> make -s
```

#### Quick demo running vecadd OpenCL kernel on 2 cores

```
SIMX
Apptainer> ./ci/blackbox.sh --cores=2 --app=vecadd --driver=simx

RTLSIM
Apptainer> ./ci/blackbox.sh --cores=2 --app=vecadd --driver=rtlsim

XRTSIM
Apptainer> ./ci/blackbox.sh --cores=2 --app=vecadd --driver=xrt
```
