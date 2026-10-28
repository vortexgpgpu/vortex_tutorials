> **MICRO 2026 (Vortex v3.0, image `vortex_micro26.sif`).** Items marked **TODO** depend on the final Rogues Gallery
> deployment: the access period, the registration form, the login address, the tutorial repository links, and the
> paths under `/projects/tools/...` (proposed, not yet created).

# Vortex Tutorial - Remote Option

We suggest that you use a remote server hosted by the [CRNCH Rogues Gallery](https://crnch-rg.cc.gatech.edu/). This option will be available until the end of the conference (**TODO:** confirm the end date for MICRO 2026).

## Register for access
Please use the [form to submit your Github ID](https://forms.office.com/r/CynuGzyeDD) to reserve a slot to use for the duration of the tutorial. (**TODO:** confirm the form link for 2026.)

## Login
Login to `crush.crnch.gatech.edu/jupyter` using your Github account. (**TODO:** confirm the login address for 2026.)

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

### Get the code
Everything you create (clones, builds, edits) must live in a directory on the server, not inside the container: the container's own writable space is only 64 MB.
```
$	git clone --branch v3.0 --recursive https://github.com/vortexgpgpu/vortex.git
$	git clone https://github.com/vortexgpgpu/vortex_tutorials.git      # TODO: confirm the tutorial repository URL
$	mkdir work
```

### Start Apptainer

The command
* uses the pre-built apptainer image and
* mounts your Vortex clone, the tutorial repository, a work directory and the shared toolchain onto the apptainer

```
$   apptainer shell --fakeroot --cleanenv --writable-tmpfs \
    --bind ./vortex:/home/vortex \
    --bind ./vortex_tutorials:/home/vortex_tutorials \
    --bind ./work:/home/work \
    --bind /projects/tools/x86_64/common-tools/vortex-tools-v3.0:/home/tools \
    /projects/tools/x86_64/containers/vortex_micro26.sif
```

(**TODO:** confirm the two `/projects/tools/...` paths once the Rogues Gallery team has installed the toolchain directory and the image.)

### Build Vortex inside Apptainer

```
Apptainer> export TUTORIAL=/home/vortex_tutorials
Apptainer> cd /home/vortex
Apptainer> mkdir build32 && cd build32
Apptainer> ../configure --xlen=32 --tooldir=$TOOLDIR
Apptainer> make -s -j4

Apptainer> echo $TOOLDIR
/home/tools

Apptainer> ls $TOOLDIR
chipstar  gem5  libc32  libc64  libcrt32  libcrt64  llvm-vortex  mesa-vortex  pocl  riscv32-gnu-toolchain  riscv64-gnu-toolchain  sta  sv2v  verilator  yosys
```

`$TOOLDIR` is already set to the toolchain mount (`/home/tools`). The toolchain is installed and the system packages are in the image, so the `./ci/toolchain_install.sh` and `./ci/install_dependencies.sh` steps of the exercise setup are not needed. Use `-j`; without it the build takes much longer.

#### Quick demo running vecadd OpenCL kernel on 2 cores

```
SIMX
Apptainer> ./ci/blackbox.sh --cores=2 --app=vecadd --driver=simx

RTLSIM
Apptainer> ./ci/blackbox.sh --cores=2 --app=vecadd --driver=rtlsim

XRTSIM
Apptainer> ./ci/blackbox.sh --cores=2 --app=vecadd --driver=xrt
```

### The exercises

Follow the [exercises](https://github.com/vortexgpgpu/vortex_tutorials/tree/main/Exercises) in the tutorial repository (**TODO:** confirm the link).
