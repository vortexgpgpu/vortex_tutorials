# Vortex Tutorial - Remote Option

We suggest that you use a remote server hosted by the [CRNCH Rogues Gallery](https://crnch-rg.cc.gatech.edu/). This option will be available until the end of the conference (November 6th)

## Register for access
Please use the [form to submit your Github ID](https://forms.office.com/r/SXUDPwuDuk) to reserve a slot to use for the duration of the tutorial.

## Login
Login to `rg-simulation.crnch.gatech.edu/jupyter` using your Github account.

Then, click "launch my server".

Once there, open the terminal application and run `cd /vortex/build`.

## Build Vortex
From the `build` directory, set up the environment with `source ./ci/toolchain_env.sh`.

Then, build Vortex with `make -j2`.

### Quick demo running vecadd OpenCL kernel on 2 cores
    ./ci/blackbox.sh --cores=2 --app=vecadd
