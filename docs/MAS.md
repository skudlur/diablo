# Diablo Microarchitecture Specification (MAS) v0.1

This document outlines the microarchitecture for the Diablo Out-of-Order (OoO) RISC-V core.

## 1. Overview
Diablo is an OoO RISC-V core written in Bluespec SystemVerilog (BSV). It aims for high performance by leveraging BSV's atomic rule semantics to simplify complex control logic (e.g., bypass networks, issue selection). It integrates with the Flute ecosystem for ISA decode types, AXI4 fabric, and caches.

## 2. Pipeline Stages
The core pipeline is built around a two-level instruction cracking approach: Macro-Ops (MOPs) and Micro-Ops ($\mu$OPs).

- **Fetch & Decode:** Uses Flute's front-end components.
- **Crack:** Translates RISC-V MOPs into one or more internal $\mu$OPs.
- **Rename & Dispatch:** Maps architectural registers to physical registers.
- **Issue:** Age-ordered tournament selection.
- **Execute:** Functional units with RWire-based bypass networks.
- **Writeback & Wakeup:** Broadcasts tags to wake up dependent instructions.
- **Commit:** In-order retire from the Reorder Buffer (ROB).

## 3. Physical Registers and Renaming
To support Out-of-Order execution, the architectural registers (32 integer, 32 floating-point per the RISC-V ISA) are renamed to a larger pool of physical registers to eliminate false dependencies (WAW, WAR).
- **Integer Physical Register File (PRF):** 96 registers
- **Floating-Point PRF:** 96 registers
- A 7-bit index (`bit [6:0]`) is sufficient to address these registers.

## 4. Reorder Buffer (ROB)
- **Entries:** 64
- **Structure:** Circular buffer (`Vector#(64, RobSlot)`)
- **Commit Width:** 2 $\mu$OPs/cycle
- **Granularity:** Per-$\mu$OP commit. A $\mu$OP marked with `is_last` represents the completion of a MOP and triggers the architectural state update.
- **Branch Tracking:** Epoch tags in slots. On a mispredict, a snapshot is restored, and younger entries are flushed.

## 5. Issue Queue
- **Entries:** 24 unified slots.
- **Dispatch Width:** 2 $\mu$OPs/cycle.
- **Issue Width:** Up to 4 $\mu$OPs/cycle (one per EU type).
- **Ordering:** Age-ordered (oldest ready $\mu$OP wins).
- **Implementation:** BSV `Vector#(24, Maybe#(IssueSlot))` with tournament select tree rules.

## 6. Execution Units
| EU | Count | Functional Units | Latency | Wakeup Type |
|----|-------|------------------|---------|-------------|
| Integer ALU / Branch | 4 | ALU + branch resolution | 1 cycle | Fast (RWire broadcast) |
| Integer ALU / Jump | 1 | ALU + jump | 1 cycle | Fast |
| Integer ALU / CSR | 1 | ALU + CSR r/w | serialising | Fast |
| Multiply | 1 | Pipelined multiplier | 3 cycles | Fast |
| Divide | 1 | Unpipelined divider | variable | Slow (writeback) |
| AGU + Load | 2 | Address gen $\rightarrow$ LQ | 4-cycle hit | Slow |
| AGU + Store | 1 | Address gen $\rightarrow$ SQ | 4-cycle hit | Slow |
| FPU | 2 | FP add/mul/cmp + FDiv | 3–20 cycles | Slow |

Bypass is explicitly handled via BSV's `RWire` and `BypassWire` during rule execution rather than a manually-multiplexed combinational path.

## 7. Load/Store Unit
- **Load Queue (LQ):** 16 entries
- **Store Queue (SQ):** 12 entries
- **MSHRs:** 4
- **Forwarding:** Store-to-load forwarding checked at load-issue time.

## 8. Branch Recovery
- Uses per-branch snapshots (8 entries total).
- On mispredict: target broadcast via RWire, ROB squashes younger entries, rename table restored from snapshot, fetch redirected. Target effective penalty: 8-10 cycles.

## 9. Integration with Flute
Flute is utilized as a git submodule to provide:
- `ISA_Decls.bsv` and similar type definitions.
- L1/L2 caches and AXI4 fabric.
- Tandem Verification infrastructure.
