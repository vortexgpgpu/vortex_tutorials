# Assignment #5: How to add a new instruction 

In this assignment, we will learn how to add a new instruction using intrinsics and by extending the pipeline. You will add a software prefetch instruction. You have to modify Sim-X, a functional simulator of Vortex before adding the new instruction in the pipeline (RTL programming). Since software prefetch is an instruction that is not currently supported by the RISC-V toolchain, you will first have to insert the new instruction using assembly code. 

---

## Step 1: Adding a new intrinsic: 

- Since software prefetch is not currently supported by the RISC-V toolchain, you will start by inserting the instruction in /Vortex/runtime/include/vx_intrinsics.h using assembly code.

  ``` c++
  // Assignment 5
  // Prefetch the next cache line during a load request
  inline void vx_prefetch(unsigned address){
      asm volatile (".insn s 0x6b, 5, x0, 0(%0)" :: "r" (address));
  }
  ```

- *insn* is the opcode for instructions not defined by RISC-V.
  
- *5* is the identifier for the instruction. Identifiers 0-4 have already been used.
  
- The software prefetch instruction takes only one argument: the load address. 

---

## Step 2: Defining a new instruction in simX:
  
### 2a: Decoding the new instruction:

- The opcode for Vortex RISC-V extensions is *GPGPU*
  
- In lines 178-185 of /Vortex/simX/decode.cpp
  
  ``` c++
  // Assignment 5
  case 5: return "PREFETCH";
  ```

### 2b: Executing the new instruction:

- For now, all we want to do is print the prefetch address when the instruction is executed. We are not worried about the details of the implementation yet since our goal for now is to understand how a new instruction is added.
  
- In lines 908-914 of /Vortex/simX/execute.cpp
  
  ``` c++
  // Assignment 5
  case 5: {
  // PREFETCH
    int addr = rsdata[0];
    printf("*** PREFETCHED %d *** \n", addr);
  } break;
  ```

- *rsdata* contains the prefetch address. Since the prefetch intrinsic uses only one register for the address, we use *rsdata[0]* to get the prefetch address and we print the address in the case statement.

---

## Step 3: Extending the pipeline:

### 3a: Adding the opcode for prefetch:

- As mentioned before, the opcode for Vortex RISC-V instructions is *0x6b*. The opcode is defined in /Vortex/hw/rtl/VX_define.vh
  
  ``` verilog
  `define INST_GPU        7'b1101011
  ```

- However, we still need to add an identifier for the software prefetch instruction. This is to distinguish software prefetch from the tmc, wspawn, split, join and bar instructions (which all use the same opcode). In /Vortex/hw/rtl/VX_define.vh:
  
  ``` verilog
  // Assignment 5
  `define GPU_PREFETCH    3'h5
  ```

### 3b: Adding a tag to indicate that the instruction is a prefetch request:

- For the prefetch instruction to move from the decode to the execute stage, we need to add an additional prefetch bit to all the interfaces it passes through.

- Software prefetch goes through the following stages in the vortex pipeline:
  
  [ *Fetch* ] -> [ *Decode* ] -> [ *Instruction Buffer* -> *Issue* -> *Instruction Demultiplexer* ] -> [ *Execute* -> *LSU unit*] 

- You need to modify the interfaces to these pipeline stages in /Vortex/hw/rtl/intertfaces.

- In /Vortex/hw/rtl/interfaces/VX_decode_if.v, VX_ibuffer_if.v, and VX_lsu_req_if.v:

  ``` verilog
  // Assignment 5
  wire prefetch;
  ```

### 3c: Decoding the opcode for prefetch:

- First, you need to add an additional structure to the decoder to indicate whether the current instruction is a software prefetch. In /Vortex/hw/rtl/VX_decode.v:

  ``` verilog
  // Assignment 5
  reg is_prefetch;
  ```
- You want to make sure that you reset this bit whenever the instruction is *not* a software prefetch

  ``` verilog
  // Assignment 5
  is_prefetch = 0;  
  ```

- This bit is set in the switch case statement for the GPGPU opcode and the software prefetch identifier *5*. Software prefetch executes in the LSU in contrast to the other Vortex instructions which execute in the GPU.

  ``` verilog
  // Assignment 5
  3'h5: begin
      ex_type = `EX_LSU;
      op_type = `OP_BITS'(`GPU_PREFETCH);
      is_prefetch = 1;
      `USED_IREG(rs1);
  end
  ```

- After modifying the prefetch bit, you can finally push it into the decode interface from where it hops to different pipeline stages before reaching the LSU unit.
  
  ``` verilog
  // Assignment 5
  assign decode_if.prefetch = is_prefetch;
  ```

### 3d: Moving the prefetch instruction through the pipeline stages:

- Your next task is to relay the prefetch bit from one interface to the next through the pipeline stages.

- [ *Decode* ] -> [ *Instruction Buffer* ]\
In /Vortex/hw/rtl/VX_ibuffer.v:
  
  ``` verilog
  // Assignment 5
  // Adding 1 to DATAW to accomodate the prefetch tag
  localparam DATAW   = `NUM_THREADS + 32 + `EX_BITS + `OP_BITS + `FRM_BITS + 1 + (`NR_BITS * 4) + 32 + 1 + 1 + `NUM_REGS + 1;
  ```

  ``` verilog
  assign q_data_in = {...,
                      decode_if.prefetch};
  assign {...,
          decode_if.prefetch} = deq_instr;
  ```

- [ *Instruction Buffer* ] -> [ *Issue* ] -> [ *Instruction Demultiplexer* ]\
In /Vortex/hw/rtl/VX_issue.v:

  ``` verilog
  // Assignment 5
  assign execute_if.prefetch  = ibuffer_if.prefetch;

  VX_instr_demux instr_demux (
      ...
      .ibuffer_if (execute_if),
      ...
  );
  ```

- [ *Instruction Demultiplexer* ] -> [ *LSU Unit* ]\
In /Vortex/hw/rtl/VX_instr_demux.v

  ``` verilog
  // Assignment 5
  // Passing the prefetch tag from ibuffer_if to lsu_req_if
  VX_skid_buffer #(
      // Adding 1 to DATAW to accomodate the prefetch tag
      .DATAW (`NW_BITS + `NUM_THREADS + `XLEN + `LSU_BITS + 1   + `XLEN + `NR_BITS + 1 + (2 * `NUM_THREADS * `XLEN) + 1),
      .OUTPUT_REG (1)
  ) lsu_buffer (
      ...,
      .data_in  ({...,
                ibuffer_if.prefetch}),
      .data_out ({...,
                lsu_req_if.prefetch}),
      ...
  );
  ```

### 3e: Modifying the LSU unit to take in prefetch instructions:

- Right now, the LSU takes in only load and store instructions. To enable the LSU to accept prefetch instructions, we need to add a tag to indicate that an instruction is a software prefetch. 

- In /Vortex/hw/rtl/VX_lsu

  ``` verilog
  // Is the current instruction a software prefetch?
  reg instr_is_prefetch = lsu_req_if.prefetch;

  // Combining load and software prefetch
  reg is_wb = req_wb | instr_is_prefetch;
  assign req_wb = is_wb;
  ```
---

## Step 5: Developing a test for software prefetch:

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

- To test your code, use ./ci/blackbox.sh --cores=4 --app=prefetch

---

## Step 6: Results and Debugging

### SimX

``` bash
./ci/blackbox.sh --driver=simx --cores=4 --app=prefetch
```

``` bash
...
Device running...
*** PREFETCHED 1024 *** 
*** PREFETCHED 1280 *** 
*** PREFETCHED 1536 *** 
*** PREFETCHED 1792 *** 
*** PREFETCHED 5120 *** 
...
```


### RTL

- Run the following commands to isolate the prefetch requests in run.log

  ``` bash
  ./ci/blackbox.sh --driver=rtlsim --cores=4 --app=prefetch   --debug
  ```
  
  ``` bash
  grep ‘D$0 Rd Req’ run.log | grep ‘PC=800000cc’

  169149: D$0 Rd Req: wid=2, PC=800000cc, tmask=1111, addr={0xbcc, 0xacc, 0x9cc, 0x8cc}, tag=3, byteen=ffff, type={0x0, 0x0, 0x0, 0x0}, rd=11, is_dup=0, req_is_prefetch=1, instr_is_prefetch=1

  185565: D$0 Rd Req: wid=3, PC=800000cc, tmask=1111, addr={0xff4, 0xef4, 0xdf4, 0xcf4}, tag=6, byteen=ffff, type={0x0, 0x0, 0x0, 0x0}, rd=11, is_dup=0, req_is_prefetch=1, instr_is_prefetch=1
  ```

- As you can see, requests to the cache are sent in batches. There are 2 batches of requests to the D-cache where all four threads generate a valid request.

  ``` bash
  grep ‘D$0 Rsp’ run.log | grep ‘PC=800000cc’

  169467: D$0 Rsp: wid=2, PC=800000cc, tmask=0001, tag=3,   rd=11, data={0x68423cf9, 0x6ee0a219, 0xe6d2de87, 0x232}addr=  {0xab9490f9, 0xab948ff9, 0xab948ef9, 0xab948df9}, is_dup=0,   rsp_is_prefetch=1, instr_is_prefetch=0

  169469: D$0 Rsp: wid=2, PC=800000cc, tmask=0010, tag=3,   rd=11, data={0x68423cf9, 0x6ee0a219, 0x272, 0x65bcc4e0}addr=  {0x87c8, 0x86c8, 0x85c8, 0x84c8}, is_dup=0,   rsp_is_prefetch=1, instr_is_prefetch=1

  169471: D$0 Rsp: wid=2, PC=800000cc, tmask=0100, tag=3,   rd=11, data={0x68423cf9, 0x2b2, 0xe6d2de87, 0x65bcc4e0}addr=  {0xab9494f9, 0xab9493f9, 0xab9492f9, 0xab9491f9}, is_dup=0,   rsp_is_prefetch=1, instr_is_prefetch=0

  169473: D$0 Rsp: wid=2, PC=800000cc, tmask=1000, tag=3,   rd=11, data={0x2f2, 0x6ee0a219, 0xe6d2de87, 0x65bcc4e0}addr=  {0xab949024, 0xab948fe4, 0xab948fa4, 0xab948f64}, is_dup=0,   rsp_is_prefetch=1, instr_is_prefetch=0

  186135: D$0 Rsp: wid=3, PC=800000cc, tmask=0001, tag=6,   rd=11, data={0x68423cf9, 0x6ee0a219, 0xe6d2de87, 0x33c}addr=  {0x8bf0, 0x8af0, 0x89f0, 0x88f0}, is_dup=0,   rsp_is_prefetch=1, instr_is_prefetch=1

  186137: D$0 Rsp: wid=3, PC=800000cc, tmask=0010, tag=6,   rd=11, data={0x68423cf9, 0x6ee0a219, 0x37c, 0x65bcc4e0}addr=  {0xab949921, 0xab949821, 0xab949721, 0xab949621}, is_dup=0,   rsp_is_prefetch=1, instr_is_prefetch=0

  186139: D$0 Rsp: wid=3, PC=800000cc, tmask=0100, tag=6,   rd=11, data={0x68423cf9, 0x3bc, 0xe6d2de87, 0x65bcc4e0}addr=  {0xab94912e, 0xab9490ee, 0xab9490ae, 0xab94906e}, is_dup=0,   rsp_is_prefetch=1, instr_is_prefetch=0

  186141: D$0 Rsp: wid=3, PC=800000cc, tmask=1000, tag=6,   rd=11, data={0x3fc, 0x6ee0a219, 0xe6d2de87, 0x65bcc4e0}addr=  {0xab94912e, 0xab9490ee, 0xab9490ae, 0xab94906e}, is_dup=0,   rsp_is_prefetch=1, instr_is_prefetch=0
  ```

---