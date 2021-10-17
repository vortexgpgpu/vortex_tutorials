# Assignment #5: How to add a new instruction 

In this assignment, you will learn how to add a new instruction by using intrinsics and extending the pipeline. You will add a software prefetch instruction. You will first add the new instruction to Sim-X, a functional simulator of Vortex, before implementing it in the pipeline (RTL programming). Since software prefetch is an instruction that is not currently supported by the RISC-V toolchain, you will first have to insert the new instruction using assembly code. 

---

## Step 1: Adding a new intrinsic: 

You will begin by inserting the instruction in [/Vortex/runtime/include/vx_intrinsics.h](https://github.com/vortexgpgpu/vortex/blob/e2b5799a013b98f067ee8aaeda07ea3c979ef546/runtime/include/vx_intrinsics.h#L86) using assembly code.

#### Hints

- *0x6b* is the opcode for instructions not defined by RISC-V.
  
- *5* is the identifier for the instruction. Identifiers 0-4 have already been used. The purpose of an instruction identifier is to distinguish software prefetch from the tmc, wspawn, split, join and bar instructions (which all use the same opcode).
  
- The software prefetch instruction takes only one argument: the load address. 

---

## Step 2: Defining a new instruction in simX:
  
### 2a: Decoding the new instruction:

Following the pattern of how the other Vortex RISC-V instructions are implemented, decode the opcode for software prefetch in [/Vortex/sim/simX/decode.cpp](https://github.com/vortexgpgpu/vortex/blob/73d249fc56a003239fecc85783d0c49f3d3113b4/sim/simX/decode.cpp#L184).

### 2b: Executing the new instruction:

For now, all we want to do is print the prefetch address when the instruction is executed in [/Vortex/sim/simX/execute.cpp](https://github.com/vortexgpgpu/vortex/blob/73d249fc56a003239fecc85783d0c49f3d3113b4/sim/simX/execute.cpp#L714). We are not worried about the details of the implementation yet since our goal for now is to simply understand how a new instruction is added.
  
#### Hints

- *rsdata* contains the prefetch address. Since the prefetch intrinsic uses only one register for the address, we use *rsdata[0]* to get the prefetch address and we print the address in the case statement.

---

## Step 3: Extending the pipeline:

### 3a: Adding the opcode for prefetch:

As mentioned before, the opcode for Vortex RISC-V instructions is *0x6b* and is defined in [/Vortex/hw/rtl/VX_define.vh](https://github.com/vortexgpgpu/vortex/blob/e2b5799a013b98f067ee8aaeda07ea3c979ef546/hw/rtl/VX_define.vh#L67). The instruction identifier *5* for software prefetch has also been defined [here](https://github.com/vortexgpgpu/vortex/blob/e2b5799a013b98f067ee8aaeda07ea3c979ef546/hw/rtl/VX_define.vh#L188).
  

### 3b: Decoding the prefetch instruction:

In [/Vortex/hw/rtl/VX_decode.sv](https://github.com/vortexgpgpu/vortex/blob/e2b5799a013b98f067ee8aaeda07ea3c979ef546/hw/rtl/VX_decode.sv#L377), you will need to add a case for the identifier *5*. 

#### Hints

- Software prefetch executes in the LSU
- The immediate field which contains the address needs to be sign extended to 32 bits
- Software prefetch is designed to mimic a load instruction while ignoring the load responce. Hence, the rd register is not used.

### 3c: Adding a tag to identify a prefetch instruction:

- You need to add a tag to [/Vortex/hw/rtl/interfaces/VX_lsu_req_if.sv](https://github.com/vortexgpgpu/vortex/blob/73d249fc56a003239fecc85783d0c49f3d3113b4/hw/rtl/interfaces/VX_lsu_req_if.sv#L19) to distinguish a software prefetch from a load.

- You will need to modify the value of this tag in [Vortex/hw/rtl/VX_instr_demux.sv](https://github.com/vortexgpgpu/vortex/blob/dd12d3f848d25367d3e143d1e7242840a2012156/hw/rtl/VX_instr_demux.sv#L62) since you want to set the tag before the instruction reaches the LSU unit.

- We mimic the behavior of a load my modifying the req_wb signal in [/Vortex/hw/rtl/VX_lsu_unit.sv](https://github.com/vortexgpgpu/vortex/blob/73d249fc56a003239fecc85783d0c49f3d3113b4/hw/rtl/VX_lsu_unit.sv#L89). We make the cache response invalid if it comes from a prefetch request.

---

## Step 4: Developing a test for software prefetch:

- A test to check the working of the fence instruction has already been developed in /Vortex/tests/regression/fence.

- Duplicate this folder, rename it to prefetch, and modify the PROJECT=fence line inside the Makefile to PROJECT=prefetch
  
- Inside the for loop in kernel.c, add the following line:
  
  ``` c
  for (uint32_t i = 0; i < count ; ++i) {
		...
		vx_prefetch(src0_ptr + offset + i); 
  }
  ```

- Compile the modified prefetch kernel. You should see a new opcode in the kernel body of kernel.dump

  ```
  800000cc:	0007d06b          	0x7d06b
  ```

- *0x7d06b* is the opcode for prefetch. Prefetch can be distinguished from the other instructions since it doesn't have an assembly syntax.

---

## Step 6: Results and Debugging

### SimX

``` bash
./ci/blackbox.sh --driver=simx --cores=4 --app=prefetch
```

### RTL

``` bash
./ci/blackbox.sh --driver=rtlsim --cores=4 --app=prefetch   --debug
```   
---