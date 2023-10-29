# Vortex tutorials at [MICRO-56 (29th October 2023)](https://microarch.org/micro56/index.php)

Description:

[Vortex](http://vortex.cc.gatech.edu/) is an [open-source](https://github.com/vortexgpgpu/) hardware and software project to support GPGPU based on RISC-V ISA extensions. Currently, Vortex supports OpenCL/CUDA and it runs on FPGA. The Vortex platform is highly customizable and scalable with a complete open-source compiler, driver and runtime software stack to enable research in GPU architectures. In this tutorial, we will cover Vortex's hardware, software, applications, and provide hands-on exercises.

## Date: 2023-10-29 (1:00PM - 5:00PM EDT)

## Organizers:

Blaise Tine, Hyesoon Kim, Jeff Young, Liam Cooper, Chihyo (Mark) Ahn, Shinnung Jeong

## Registration

How to register: [MICRO-56 registration link](https://microarch.org/micro56/attend/register.php)

## Tentative Tutorial Schedule

| Time      | Contents                                                             | Presenter      | slides |
|-----------|----------------------------------------------------------------------|----------------|--------|
| 1:00-1:30 | Intro and GPU background                                             | Hyesoon Kim    |        |
| 1:30-2:00 | Vortex Microarchitecture                                             | Blaise Tine    |        |
| 2:00-3:00 | Vortex Code Review                                                   | Blaise Tine    |        |
| 3:00-3:30 | Q&A and Break                                                        |                |        |
| 3:30-3:50 | Vortex Software Stack                                                | Shinnung Jeong     |        |
| 3:50-4:10 | CupBop/Running OpenCL/CUDA on Vortex                                 | Chihyo Ahn |        |
| 4:10-4:20 | Vortex FPGA demo   & Tutorial Assignments                            | Liam Cooper    |        |
| 4:20-4:40 | Discussions for Academic Usages with Vortex | Hyesoon Kim    |        |
| 4:30-5:00 | Hands-on Exercises                                                   |                |        |

## Tutorial Assignments

* [Assignment 1](Exercises/assignment1.md) and [assignment 2](Exercises/assignment2.md): Adding simple hardware performance counters
* [Assignment 3](Exercises/assignment3.md) and [assignment 4](Exercises/assignment4.md): Adding hardware prefetcher and learning to debug
* [Assignment 5](Exercises/assignment5.md): Adding software prefetching & simx modification
* [Assignment 6](Exercises/assignment6.md): Adding performance counters to test the software prefetcher

### Solutions
Solutions are available for [assignment 3](https://github.com/vortexgpgpu/vortex_tutorials/blob/main/Solutions/assignment3_solution.md) and [assignment 5](https://github.com/vortexgpgpu/vortex_tutorials/blob/main/Solutions/assignment5_solution.md).

## Mailing list
For tutorial info please join vortex-dev@lists.gatech.edu 

## VM Images
VM Access (recommended): please see the [VM README](VM_Imgs/VM_README.md) to get instructions for downloading and running the Vortex tools using Vagrant and VirtualBox.

## Remote Access
If you are not able to download and use the VM, the alternative is to use the Open OnDemand terminal interface hosted by the [CRNCH](https://crnch.gatech.edu/) Rogues Gallery. [Instructions can be found here](REMOTE_ACCESS.md).

## System Set Up Instructions
If you would like to set up Vortex on your own system instead of using a VM or remote access, instructions can be found [here](https://github.com/vortexgpgpu/vortex/blob/master/README.md) and pre-built toolchain details [here](https://github.com/vortexgpgpu/vortex-toolchain-prebuilt); they are for Linux (Ubuntu 18.04) systems only.

## Relevant Repos

* [Vortex](https://github.com/vortexgpgpu/vortex)
