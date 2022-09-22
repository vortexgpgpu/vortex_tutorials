# Vortex tutorials at [MICRO-55 (1st October 2022)](https://www.microarch.org/micro55/index.php)

Description:

[Vortex](http://vortex.cc.gatech.edu/) is an [open-source](https://github.com/vortexgpgpu/) hardware and software project to support GPGPU based on RISC-V ISA extensions. Currently, Vortex supports OpenCL/CUDA and it runs on FPGA. The Vortex platform is highly customizable and scalable with a complete open-source compiler, driver and runtime software stack to enable research in GPU architectures. As an application session, we will also have how to run drone applications on FPGA.

## Date: 2022-10-1 (8AM CST - 12:00PM CST)

## Organizers:

Hyesoon Kim, Blaise Tine, Ruobing Han, Sam Jijina, Liam Cooper, Jeff Young (Georgia Institute of Technology)

## Registration

How to register: [MICRO-55 register link](https://whova.com/portal/registration/miism_202210/)

## Tentative Tutorial Schedule

|  Time | Contents  |
|---|---|

| 8:00-8:30 | Intro and GPU background |
| 8:30-9:00 | Vortex Microarchitecture |
| 9:00-10:00 | Vortex Code Review |
| 10:00 - 10:20 |Q&A and Break |
| 10:20-11:00 | Vortex Software |
| 11:00-11:10 | Vortex FPGA demo |
| 11:10-11:30 | Tutorial assignments and assignment #1 demo |
| 11:30-12:00 | drone applications |

## Tutorial Assignments

* [Assignment 1](Exercises/assignment1.md) and [assignment 2](Exercises/assignment2.md): adding simple hardware performance counters
* [Assignment 3](Exercises/assignment3.md) and [assignment 4](Exercises/assignment4.md): adding hardware prefetcher and how to debug 
* [Assignment 5](Exercises/assignment5.md): adding software prefetching & Sim-X modification
* [Assignment 6](Exercises/assignment5.md): adding performance counters to test the software prefetcher

### Solutions
Solutions are available for [assignment 3](https://github.com/vortexgpgpu/vortex_tutorials/blob/main/Solutions/assignment3_solution.md) and [assignment 5](https://github.com/vortexgpgpu/vortex_tutorials/blob/main/Solutions/assignment5_solution.md).

## Mailing list
For tutorial info please join vortex-dev@lists.gatech.edu 

## VM Images

VM Access (recommended): please see the [VM README](VM_Imgs/VM_README.md) to get instructions for downloading and running the Vortex tools using Vagrant and VirtualBox.b

## Local Tutorial Set Up Instructions
* Build instructions can be found [here](https://github.com/vortexgpgpu/vortex/blob/master/README.md) and pre-built toolchain details [here](https://github.com/vortexgpgpu/vortex/blob/master/docs/execute_opencl_on_vortex.md); they for Linux (Ubuntu 18.04) users only.

## Relevant Repos

* [Vortex](https://github.com/vortexgpgpu/vortex) 
* [POCL](http://portablecl.org)
