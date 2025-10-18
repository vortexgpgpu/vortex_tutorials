# **Assignment #10: Add `fmaf()` Support in CuPBoP**
 
This assignment introduces how to extend **CuPBoP**, a framework designed to execute **unmodified CUDA source code** on **Vortex**, to support new CUDA math functions.  

In this task, you will **add `fmaf()` (fused multiply-add)** support to the framework — enabling CuPBoP to correctly translate and execute kernels using this CUDA intrinsic.
 
`fmaf()` performs a fused multiply-add operation: $ fmaf(a, b, c) = a \times b + c $
 
with a single rounding, improving both **precision** and **performance**.
 
---
 
## **Setting Up CuPBoP**
 
Before starting, make sure CuPBoP is properly built and runnable.
 
📄 Refer to the setup guide:  

[NonKiaVolvoSetup.md](https://github.com/cupbop/CuPBoP_Vortex/blob/master/docs/NonKiaVolvoSetup.md)
 
1. **Install CUDA toolkit** and download CUDA header files.  

2. **Set up environment variables** using `CuPBoP_env_setup.sh`.  

3. **Build the project** following the official setup instructions.  
 
---
 
## **Step 1: Create a New fmaf() Test**
 
Start by creating a small CUDA example that calls `fmaf()`.

1. Create a new test file under `examples/`.  

   Example: `examples/test_fmaf.cu`

2. Run the example to generate LLVM IR (e.g., `0.ll`) and locate the corresponding `fmaf` call in the output.  

   You can inspect it using:

    `./kjrun_llvm18.sh examples/test_fmaf.cu`

    `cat 0.ll | grep fmaf`
 
 
3.	Confirm that the fmaf function is currently undefined or unimplemented in the CuPBoP runtime.
 
## **Step 2: Implement Function Removal Logic**
 
CuPBoP’s translator must detect and replace the CUDA `fmaf()` intrinsic with your custom runtime implementation.
 
1.	Update the function removal logic inside:

    `compilation/KernelTranslation/src/tool.cpp`

2. 	Add a handler to identify and remove the IR-level function definition of `fmaf`
 
This ensures the compiler doesn’t attempt to call the undefined CUDA version during translation.
 
## **Step 3: Implement fmaf() in the Runtime Library**

Next, reimplement the `fmaf()` function in CuPBoP’s runtime layer to provide a compatible implementation for Vortex.
 
Modify:
 
•	Runtime source:

`runtime/src/vortex/kernel/cudaKernelImpl.cpp`
 
•	Corresponding header:

`runtime/include/cudaKernelImpl`.


## **Step 4: Verify the Implementation**
 
Re-run your test and ensure that the fmaf() function works correctly.
 
1.	Rebuild the framework:

	    `make clean && make`

2. 	Re-run your test:	
 