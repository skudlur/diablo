# Diablo AI Assistant - Prompt Reference

This document serves as the central context and tracking file for our work on the Diablo RISC-V processor project.

## Objectives
- Transition the core implementation from SystemVerilog/Spade HDL to Bluespec BSV.
- Implement a full Out-Of-Order pipeline based on the Diablo v0.1 Design Reference.
- **Milestone 0 (M0 - Diablo Foundations):** Pass basic `riscv-tests RV64I` in Bluesim.
- Leverage `Flute` and `Toooba` repositories (located in `../work/`) for reusable infrastructure (ISA decode, memory, testbench).

## Things to Keep in Mind
- **Code Rules:** Follow the conventions outlined in `coderule.md`.
- **Commit Rules:** Use appropriate tags (`Added:`, `Fix:`, `Impl:`, `Cleanup:`).
- **BSV-Native Design:** Treat issue, execute, and writeback as atomic rules. Rely on BSV's scheduler for hazard correctness.
- **Two-Level Decode:** Maintain strict separation between MacroOps (MOPs) and MicroOps (µOPs) to keep the backend uniform.

## Tasks to Do
- [x] **Phase 1: Project Scaffolding & Types**
  - [x] Update `Makefile` to include BSV compilation flags and paths to `Flute` and `Toooba` dependencies.
  - [x] Flesh out `src/DiabloTypes.bsv` with core structs (`UopType`, `Uop`, `RobSlot`, `IssueSlot`, rename table types).
- [x] **Phase 2: Front-End & Rename**
  - [x] Implement Fetch stage (simple aligned fetch window feeding an 8-entry FIFOF).
  - [x] Implement Decode/Crack stage (2-wide decode translating `Flute` instructions to MOPs/µOPs).
  - [x] Implement Rename stage (96-entry physical register free list, rename table, 8-entry branch snapshot array).
- [x] **Phase 3: The OoO Engine**
  - [x] Implement 24-entry Unified Age-Ordered Issue Queue.
  - [x] Implement 64-entry Reorder Buffer (ROB) and per-µOP commit logic.
  - [x] Implement Execution Units (starting with simple Integer ALUs) and `RWire`-based wakeup/bypass.
- [x] **Phase 4: Integration & M0**
  - [x] Wire the pipeline rules together.
  - [x] Set up Bluesim/Verilator testbench to execute the basic pipeline (M0 integration complete).

- [x] **Phase 5: Milestone 1 - ISA Compliance & Flute Integration**
  - [x] Connect Flute's `fv_decode` to `DecodeStage.bsv` for full `RV64I` instruction decoding.
  - [x] Integrate Flute's `I_MMU_Cache` (via `mkNear_Mem`) and AXI4 memory fabric into `DiabloCore`.
  - [x] Connect `FetchStage.bsv` to the `I_MMU_Cache` for real memory-backed instruction fetches.
  - [x] Expand Execution Units (Branch resolution, Memory AGU, Integer Multiplier).
  - [x] Implement precise state rollback and Branch prediction snapshot restoration.
  - [x] Integrate a basic Data Cache/Memory interface for Load/Store operations.
  - [x] Set up the testbench to load and execute `riscv-tests` binaries.

- [ ] **Phase 6: Microarchitecture Performance Improvements**
  - [ ] Review performance bottlenecks limiting the core to 0.84 CoreMark/MHz.
  - [ ] Identify and implement Out-of-Order structures (e.g. better branch prediction, load/store queue forwarding, larger issue queues, superscalar execution) to increase IPC.

## Tasks Completed
- [x] Converted the Diablo v0.1 Design Reference DOCX into Markdown (`docs/Diablo_v0.1_Design_Reference.md`).
- [x] Updated the `README.md` to indicate the transition to Bluespec BSV.
- [x] Reviewed Design Reference and formulated development plan.
- [x] Cloned `Flute` and `Toooba` references into `/home/skudlur/work/`.

## Tasks Done but Not Successfully
- [ ] *[Tasks that were attempted but need to be revisited or abandoned]*

## Debugging Notes & Findings
- **MMIO Collision Avoidance**: The `riscv-tests` suite writes data to a `begin_signature` area starting at `0x8000_2000`. If hardware MMIO (like the UART or Cycle Counter) is placed at `0x8000_2000` (which is often a default in baremetal setups), it will swallow test verification stores. The UART was moved to `0xC000_0000` and the Cycle Counter to `0xC000_0008` in both the `ExecutionUnit.bsv` AGU and the `core_portme.c`/`syscalls.c` C software layers.
- **Testbench Memory Model UART Bug**: Even after moving the hardware UART intercept, stores (`sb`, `sh`, `sw`, `sd`) were still failing because `test/AXI4_Mem_Model.bsv` (the simulation memory fabric model) *also* had a hardcoded `0x8000_2000` UART intercept condition, which caused the testbench to silently drop AXI writes to `0x8000_2000` instead of updating the RAM array. 
- **Flute Cache Sub-Word Store Expectations**: When sending `dmem.req` to the Flute `MMU_Cache` for sub-word stores (like `sb` or `sh`), the cache expects the CPU to provide the store data *unshifted* (i.e. right-justified in the lower bits of the 64-bit value, such as `[7:0]` for a byte store). The cache itself handles byte lane shifting and generating the correct AXI4 `WSTRB` values.
- **`fence_i` Test Timeout**: The `rv64ui-p-fence_i` test deliberately skips or times out (after ~20M cycles) because it utilizes self-modifying code, which our Out-of-Order processor does not quickly/fully synchronize (the I-cache and pipeline aren't fully flushed). This is expected for this core milestone.
- **Current Baselines**: The core achieved 0.84 CoreMark/MHz and 0.42 DMIPS/MHz prior to architectural improvements.

## Handover / Next Steps
- **State**: The `diablo` repository is currently clean and the user is preparing to commit the baseline implementation. All `riscv-tests RV64I` (except `fence_i`) are passing with 100% success.
- **Action Required**: The next agent should focus on analyzing the baseline microarchitecture and implementing improvements to increase CoreMark and Dhrystone scores (Phase 6). Look into IPC bottlenecks, branch prediction, and memory subsystem latency.
