# Vortex tutorials at [MICRO-54](https://www.microarch.org/micro54/index.php)  (Oct 18 2021) 

Description:

[Vortex](http://vortex.cc.gatech.edu/)  is an [open source](https://github.com/vortexgpgpu/) Hardware and Software project to support GPGPU based on RISC-V ISA extensions. Currently Vortex supports OpenCL/CUDA and it runs on FPGA. The vortex platform is highly customizable and scalable with a complete open source compiler, driver and runtime software stack to enable research in GPU architectures. 


## Date: 2021-10-18 (10:00 AM EDT- 1:00 PM EDT)

## Organizers:

Hyesoon Kim,  Blaise Tine, Ruobing Han, Liam Cooper, Jeff Young (Georgia Institute of Technology) 

## Registration 

How to register: [MICRO54 register link](https://whova.com/portal/registration/miism_202110/) 



## Tutorial schedule

|  Time | Contents  | Presenter   | Slides  | Notes  |
|---|---|---|---|---|
| 10:00-10:20 |   Introduction of vortex and GPGPU backgrounds |Hyesoon Kim  | [slides0](Slides/0.tutorial_introduction.pptx) [slides1](Slides/1.gpu_arch.pptx)  |   |
| 10:20-10:40  |  Vortex microarchitecture Basic   |  Blaise Tine | [slides2](Slides/2.vortex_microarchitecture.pptx)  |   |
| 10:40-11:10  |  Vortex code structure review   |    Blaise Tine  | [slides3](Slides/3.code_structure.pptx)  |   |
| 11:10-11:30  |  Introduction of Vortex software stack | Ruobing Han | [slides4](Slides/4.vortex_software_stack.pptx) |  | 
| 11:30-11:45  |  Running OpenCL/Cuda on Vortex | Ruobing Han |[slides5](Slides/5.vortex_opencl_cuda_support.pptx)   |  | 
| 11:45-11:55 | Break   |  |  | 
|11:55 - 12:05 | Running Vortex on FPGA | Liam Cooper | [demo_video](Slides/vortex_fpga_demo.mp4) | |
|12:05 - 12:30 | Introduction of tutorial assignments and assignment #1 demo | Liam Cooper |[slides6](6.vortex_hands_on.pptx) | | 
|12:30 - 12:40 | Conclusions & Discussions |  Hyesoon Kim |  | 
|12:40 - 1:00 |  Help for tutorial  | | | | 


## Tutorial Assignments 

* [assignment1](Exercises/assignment1.md) and [assignment2](Exercises/assignment2.md): adding simple hardware performance counters. 

* [assignment3](Exercises/assignment3.md) and [assignment4](Exercises/assignment4.md): adding hardware prefetcher and how to debug 
* [assignment5](Exercises/assignment5.md) adding software prefetching & Sim-X modification 


## Mailing list 
For tutorial's info please join vortex-dev@lists.gatech.edu 

## VM Images and Remote Temporary Accounts

[Remote Access for the MICRO-54 Vortex GPGPU tutorial](https://github.com/gt-crnch-rg/vortex_tutorials/blob/main/Remote%20Access%20for%20the%20MICRO-54%20Vortex%20GPGPU%20tutorial.md)

VM Access (Optional): Please see the ["VM README"](VM_Imgs/VM_README.md) to get instructions for downloading and running the Vortex tools using Vagrant and VirtualBox. 

For remote account access, please see [this page](Remote%20Access%20for%20the%20MICRO-54%20Vortex%20GPGPU%20tutorial.md). If you'd like a longer-term account to work with Vortex and the tools, please [request an account for the Rogues Gallery testbed here](https://crnch-rg.cc.gatech.edu/request-access/).

## Relevant Repos 

* [Vortex](https://github.com/vortexgpgpu/vortex) 
* [POCL](http://portablecl.org) 

## Tutorial Set Up instructions 
* [Use pre-built toolchain](https://github.com/vortexgpgpu/vortex/blob/master/doc/execute_opencl_on_vortex.md)(Ubuntu18.04 users only)
