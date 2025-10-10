# Vortex Workshop and Tutorials at [MICRO-58 (18th October 2025)](https://microarch.org/micro58/index.php)

Description:

[Vortex](http://vortex.cc.gatech.edu/) is an [open-source](https://github.com/vortexgpgpu/) hardware and software project to support GPGPU based on RISC-V ISA extensions. Currently, Vortex supports OpenCL/CUDA and it runs on FPGA. The Vortex platform is highly customizable and scalable with a complete open-source compiler, driver and runtime software stack to enable research in GPU architectures. This event includes both a workshop and tutorial. The tutorial will cover Vortex's hardware, software, applications, and provide hands-on exercises. The workshop brings together Vortex developers and researchers to discuss and present their Vortex-related research.

## Date: 2025-10-18 (8:00AM - 12:00PM KST)

## Organizers:

Hyesoon Kim (Georgia Institute of Technology)

Blaise Tine (University of California, Los Angeles)

Jeff Young (Georgia Institute of Technology)

Chihyo (Mark) Ahn (Georgia Institute of Technology)

Shinnung Jeong (Georgia Institute of Technology)

## Tentative Tutorial and Workshop Schedule

| Time        | Contents                                    | Presenter         | slides |
|-------------|---------------------------------------------|-------------------|--------|
| 8:00-8:20   | Intro and GPU background                    | Hyesoon Kim       |  |
| 8:20-9:20   | Vortex Microarchitecture and Software Stack | Blaise Tine       | | 
| 9:20-9:40   | CuPBoP: Running OpenCL and CUDA on Vortex   | Chihyo (Mark) Ahn | ||
| 9:40-10:00  | Vortex Tutorial Assignment                           |                   |        |
| 10:00-10:30 | Q&A and Coffee Break                                |                   |        |
| 10:30-11:40 | Vortex Workshop 
| 11:40-12:00 | Review of Tutorial Assignments              |                   |        |


# Vortex Workshop Info

---

## Portable Vortex HDL for FPGA and ASIC Technologies  
**Presenters:** Jamie Kelly (enVention, LLC) and Scott O’Malia (enVention, LLC)

### Abstract
In this work, we analyze the open-source Vortex GPGPU HDL source code for portability between FPGA and ASIC target technologies. Beyond coding HDL source for legal RTL synthesis, several architecture aspects should be considered to ease technology retargeting without significant HDL source changes. Clock and reset trees and fanout control can be planned at the HDL level. Required sync and async reset types can vary with target technology, warranting a generic, global method to automatically handle each case. Special handling of clock and reset domain crossings may be required. Well-planned design hierarchy can aid floorplanning for back-end tools. Technology-specific leaf cells, such as static RAMs and arithmetic multipliers, should be wrapped using a common interface and parameter set. RAM wrappers can contain special reset control state machines to directly initialize RAM contents for many ASIC technologies that do not support this function. HDL logic pipelining and technology timing closure rely heavily on the use of flip-flop cells for delay. FPGA and ASIC flip-flop area costs are quite different, especially when complex scan-style cells are needed for ASIC manufacturing testing. The ratio of combinatorial look-up tables to flip-flops is examined. The Vortex GPGPU HDL source is analyzed for each of these cited aspects, and the results and suggested improvements are presented in this paper.

### Bios
**Jamie Kelly**  
Jamie Kelly (MS EE ‘97, MS Physics ‘07) has worked in hardware, software, FPGA, and ASIC development for more than 25 years. He has expertise in telecommunications/networking, packet switching/queuing, Linux kernel/device drivers, and end-to-end FPGA/ASIC design. Jamie currently serves as the Director of Hardware Engineering at enVention, LLC in Huntsville, Alabama, USA.

**Scott O’Malia**  
Scott O'Malia (BS MET ’09, BS EE ’13) is an Electrical Engineer at enVention, LLC with over 10 years of experience in FPGA verification, embedded systems, and safety-critical hardware/software design. His expertise includes HDL development and verification, applying DO-178/DO-254 rigor for flight-critical applications, and advancing vendor-independent FPGA verification solutions for long-term sustainment.

---

## A Configurable Mixed-Precision Fused Dot Product Unit for GPGPU Tensor Computation  
**Presenters:** Nikhil Rout (Vellore Institute of Technology) and Blaise Tine (UCLA)

### Abstract
There has been increasing interest in developing and accelerating mixed-precision Matrix-Multiply-Accumulate operations in GPGPUs for Deep Learning workloads. However, existing open-source RTL implementations of inner dot product units rely on discrete arithmetic units, leading to suboptimal throughput and poor resource utilization. To address these challenges, we propose a scalable mixed-precision dot product unit that integrates floating-point and integer arithmetic pipelines within a singular fused architecture, implemented as part of the open-source RISC-V based Vortex GPGPU’s Tensor Core Unit extension. Our design supports low-precision multiplication in FP16/BF16/FP8/BF8/INT8/UINT4 formats and higher-precision accumulation in FP32/INT32, with an extensible framework for adding and evaluating other custom representations in the future. Experimental results demonstrate 4-cycle operation latency at 362.2 MHz clock frequency on the AMD Xilinx Alveo U55C FPGA, delivering an ideal filled pipeline throughput of 11.948 GFlops in a 4-thread configuration.

---

## Virgo and Muon: Enabling Scalable Matrix Units and a New ASIC-Focused SIMT Core with Vortex
**Presenter:** Hansung Kim (UC Berkeley)

### Abstract
*Abstract text to be provided.*

### Bio
**Hansung Kim**  
Hansung Kim is a 6th-year Ph.D. student in EECS at UC Berkeley, advised by Prof. Sophia Shao. His work focuses on GPU microarchitecture and
hardware/software co-design, with strong technical expertise in RTL implementation, GPU kernel development, and SoC integration.  He is currently
on the job market for industry positions and welcomes opportunities to connect.


---




## Tutorial Assignments

Provided are seven hands-on tutorial assignments covering various aspects of Vortex:

[Assignment 1](Exercises/assignment1.md) and [Assignment 2](Exercises/assignment2.md) add a warp efficiency performance counter in Vortex's cycle-level simulator and RTL respectively.

[Assignment 3](Exercises/assignment3.md) and [Assignment 4](Exercises/assignment4.md) add software prefetching to the cycle-level simulator and RTL respectively.

[Assignment 5](Exercises/assignment5.md) and [Assignment 6](Exercises/assignment6.md) add a new custom RISC-V instruction for computing the integer dot product in the cycle-level simulator and RTL respectively.

[Assignment 7](Exercises/assignment7.md) teaches how to debug Vortex.

## Getting Vortex

### Remote Access
A terminal interface hosted by the [CRNCH Rogues Gallery](https://crnch-rg.cc.gatech.edu/) is provided. [Instructions can be found here](./REMOTE_ACCESS.md).

### Docker (Experimental)
See the [Docker instructions](./docker/README.md) for how to set up a Docker image for Vortex.

### System Set Up Instructions
If you would like to set up Vortex on your own system, [instructions can be found here](https://github.com/vortexgpgpu/vortex/blob/master/docs/install_vortex.md).

## Relevant Repos

* [Vortex](https://github.com/vortexgpgpu/vortex)
* [Vortex Toolchain](https://github.com/vortexgpgpu/vortex-toolchain-prebuilt)

## Mailing list
For tutorial info please join  https://docs.google.com/forms/d/1r8E-Yo5NwA45Hi3-kEwte4AxK0mBsYDwgjM6Bul4so0/edit
