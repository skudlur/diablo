__DIABLO__

Technical Design Reference

Volume I: BOOM Execute Stage Analysis &

Diablo v0\.1 Architecture Proposal

*Out\-of\-Order 64\-bit RISC\-V Processor in Bluespec BSV*

Target: Boot Linux · Score ≥ 4\.5 CoreMark/MHz · Dhrystone Competitive

May 2026  ·  v0\.1\-DRAFT

# __1  BOOM Execute Stage — Reference Analysis__

This section documents the execute stage of the Berkeley Out\-of\-Order Machine \(BOOMv3 / SonicBOOM\) as a reference baseline for the Diablo microarchitecture\. All observations are drawn from the BOOM source, documentation, and the pipeline diagrams reproduced in this project\.

## __1\.1  Pipeline Context__

BOOMv3 is conceptually a 10\-stage design, collapsed into 7 implementable stages\. The execute stage sits between the Issue/RegisterRead front\-end and the Memory/Writeback back\-end\.

__Stage__

__Description__

Fetch \(×4 wide\)

4\-wide instruction fetch with TAGE branch predictor

Decode / Rename

Decode \+ register renaming into physical register file

Rename / Dispatch

Dispatch µOPs into issue queues

Issue / Register Read

Select ready µOPs, read physical register file

Execute

Functional units compute results \(this section\)

Memory

TLB, D$ access for load/store µOPs

Writeback / Commit

Write results to PRF; retire in\-order from ROB

## __1\.2  Issue Queues__

BOOMv3 uses three distributed, type\-specialised issue queues\. µOPs sit in their queue until all source operands are marked ready, then compete for a dispatch slot\.

__Queue__

__Entries__

__µOP Types Accepted__

INT Issue Queue

32

Integer ALU, branch, CSR, RoCC

FP Issue Queue

32

FPU, FDiv/Sqrt

MEM Issue Queue

32

Load AGU, Store AGU

Issue select logic uses a static\-priority encoder per port\. Each port only schedules µOPs compatible with its functional unit\. This creates cascading priority: ports sharing compatible µOP types form a chain of priority encoders, which can starve older µOPs in lower\-priority slots when the ROB fills\.

## __1\.3  Physical Register Files & Bypass Network__

BOOM is a unified Physical Register File \(PRF\) design\. The PRF holds both committed architectural state and speculative in\-flight state simultaneously\.

__Register File__

__Entries__

__Read Ports__

__Write Ports__

Integer PRF

128

6 \(statically provisioned\)

3

FP PRF

128

3

2

Predicate PRF

16 bits

—

—

__Fast wakeup \(ALU\): __ALU µOPs broadcast their result tag to the issue queue in the same cycle they are issued, allowing dependent µOPs to wake up immediately\. Results are forwarded through BypassWire before the register write completes\.

__Slow wakeup \(FP / Load\): __FPU and load results are not bypassed\. The wakeup signal arrives from the register file ports during writeback\. This imposes the 4\-cycle load\-use penalty visible in the BOOMv3 pipeline diagram\.

## __1\.4  Execution Units & Functional Units__

BOOMv3 provides 8 execution ports, each a module that accepts µOPs from one issue port and contains one or more functional units\.

__Port \#__

__Execution Unit__

__Functional Units__

__Latency__

0

ALU/Branch

Integer ALU \+ Branch resolution

1 cycle

1

ALU/Branch

Integer ALU \+ Branch resolution

1 cycle

2

ALU/Branch

Integer ALU \+ Branch resolution

1 cycle

3

ALU/Branch

Integer ALU \+ Branch resolution

1 cycle

4

ALU/Jump

Integer ALU \+ Jump

1 cycle

5

ALU/CSR

Integer ALU \+ CSR read/write

1 cycle

6

ALU/RoCC

Integer ALU \+ RoCC interface

variable

7

FPU \(×2\)

FP add/mul/cmp \+ FDiv/Sqrt

3–20\+ cycles

8

AGU \(Load\)

Address generation → Load/Store Unit

4\-cycle L1 hit

9

AGU \(Store\)

Address generation → Store queue

4\-cycle L1 hit

## __1\.5  Branch Unit & Speculation__

- BOOMv3 uses a TAGE branch predictor with a 12\-cycle mispredict penalty\.
- Branch resolution occurs in the execute stage\. The branch unit computes the actual target and compares it to the predicted target from the front\-end\.
- On misprediction, the ROB is flushed back to the misspeculated instruction, the rename table snapshot is restored, and fetch is redirected\.
- In\-flight branches are tracked with epoch tags\. All µOPs younger than the mispredicted branch carry the speculative epoch and are squashed\.

## __1\.6  Memory Pipeline \(Load/Store Unit\)__

Memory µOPs compute their address in the execute stage via the AGU\. The computed address is forwarded to the Load/Store Unit for the memory stage\.

__Structure__

__Entries__

__Purpose__

Load Queue \(LQ\)

32

Track in\-flight loads; detect memory ordering violations

Store Queue \(SQ\)

32

Buffer stores until commit; forward to younger loads

MSHRs

8

Outstanding L1 D$ miss handling

Line Fill Buffers

10

L2 → L1 fill traffic

Store\-to\-load forwarding is checked at load\-issue time\. If a younger load's address matches an older uncommitted store's address, the store data is forwarded directly without accessing the cache\.

## __1\.7  Performance Penalties Summary__

__Event__

__Penalty__

__Notes__

Branch mispredict

12 cycles

Flush \+ rename snapshot restore \+ fetch redirect

Load\-use hazard

4 cycles

Load → TLB → D$ → WB; no bypass on loads

FP operation

3–20 cycles

Multi\-cycle pipelined; slow wakeup

FDiv / Sqrt

variable

Unpipelined; back\-pressure on issue queue

L1 D$ miss

~10 cycles

MSHR allocated; load queue stalls

CSR instruction

pipeline flush

Serialising; flushes all younger µOPs

## __1\.8  Identified Limitations \(Diablo Improvement Targets\)__

- Unordered issue queues create priority starvation for older µOPs when the ROB fills — branches in low\-priority slots are delayed, worsening the effective mispredict penalty\.
- Three separate issue queues increase area and complicate parameterisation\. A unified queue with tag\-based filtering can achieve equivalent scheduling with less hardware\.
- The 4\-cycle load\-use penalty is fixed by the rigid pipeline staging; a more aggressive memory pipeline could reduce this\.
- The bypass network is a separate explicit module, which in Chisel requires careful manual wiring\. BSV's RWire/BypassWire primitives can express the same semantics with compiler\-enforced correctness\.
- TAGE branch predictor without statistical correction \(SC\) or loop predictor \(L\)\. TAGE\-SC\-L offers measurably better accuracy on integer workloads\.

# __2  Diablo v0\.1 — Architecture & Microarchitecture Proposal__

Diablo is an out\-of\-order 64\-bit RISC\-V processor written in Bluespec BSV\. The design philosophy is to exploit BSV's atomic rule model and type system to produce a cleaner, more verifiable OoO implementation than Chisel\-based alternatives, while targeting performance competitive with BOOMv2–v3\.

__Design Goal__

__Target__

ISA

RV64GC \(RV64IMAFDC \+ Compressed\)

Privilege levels

M / S / U \(Linux\-capable\)

Boot target

FreeRTOS \(M2\), Linux \(M4\)

CoreMark/MHz

≥ 3\.0 at M3, ≥ 4\.5 at M5 \(BOOMv2\-competitive\)

Dhrystone

Competitive with BOOMv2 at equivalent MHz

Implementation HDL

Bluespec BSV \(bsc compiler\)

Simulation

Bluesim \+ Verilator

FPGA target

Xilinx \(Chipyard / FireSim flow\)

## __2\.1  Design Philosophy__

### __2\.1\.1  BSV\-Native, Not BOOM\-in\-BSV__

Diablo is not a transliteration of BOOM into BSV\. The microarchitecture is designed around BSV's strengths: the atomic rule model, the type system, and parameterisation via numeric type parameters\. Where BOOM uses explicit pipeline stage modules connected by handshake interfaces, Diablo uses rules\-as\-pipeline\-events with BSV's scheduler enforcing cycle\-by\-cycle correctness\.

### __2\.1\.2  Rules as Events, Not Stages__

The OoO backend is a set of atomic rules that fire when their guards are satisfied\. Issue, execute, writeback, and commit are independent rules\. The compiler's conflict analysis detects structural hazards at elaboration time rather than at simulation time\. This is a fundamentally different design style from BOOM's explicit stage\-by\-stage wiring\.

### __2\.1\.3  Infrastructure Reuse__

Diablo reuses proven BSV infrastructure to avoid reinventing solved problems\. The OoO core — the novel contribution — sits on top of this borrowed foundation\.

__Component__

__Source__

__Rationale__

ISA decode types

Bluespec Flute src\_Core/ISA/

Production\-quality, covers RV64GC completely

AXI4 fabric, CLINT, PLIC

Bluespec Flute src\_Testbench/

Linux\-proven SoC infrastructure

L1/L2 cache \+ MMU

Bluespec Flute Near\_Mem\_VM\_WB\_L1\_L2

Write\-back, boots Linux and FreeBSD

Tandem Verification

Bluespec Flute / Toooba

Instruction\-trace diffing against Spike

Debug Module

Bluespec Flute

RISC\-V debug spec, GDB integration

CSR generation

InCore Chromite CSR\-BOX approach

YAML\-driven, auto\-generates WARL logic

OoO core \(all\)

Designed fresh for Diablo

Novel contribution

## __2\.2  µOP Architecture__

### __2\.2\.1  Two\-Level Decode__

Diablo introduces a two\-level instruction decomposition that separates architectural intent from execution mechanics:

__Level 1 — MacroOp \(MOP\): __The direct output of the RISC\-V decoder\. One MOP per instruction\. Holds the full architectural context: PC, instruction word, decoded opcode class, source/destination architectural registers, and immediate\.

__Level 2 — MicroOp \(µOP\): __The unit of work dispatched to the issue queue\. A MOP cracks into 1–3 µOPs\. This provides a uniform backend interface — the execute stage never special\-cases RISC\-V instruction types\.

Cracking examples:

- Regular ALU / branch: 1 µOP \(1:1 mapping\)
- Load: 2 µOPs — AGU µOP \(address calculation\) \+ LD µOP \(cache access, carries load tag\)
- Store: 2 µOPs — AGU µOP \+ ST µOP \(data write to store queue at commit\)
- Atomic \(LR/SC/AMO\): 3 µOPs — AGU \+ load \+ conditional\-store, sequenced with dependency edges pre\-encoded in the MOP
- Fence / CSR: 1 serialising µOP that stalls issue until ROB drains

### __2\.2\.2  µOP Type Definition \(BSV\)__

The µOP struct in BSV, designed to map cleanly to the unified issue queue:

typedef enum \{ ALU, MEM\_AGU, MEM\_LS, BRANCH, FP, SYS, ROCC \} UopType deriving \(Bits, Eq\);

typedef struct \{

  MopId       mop\_id;      // links back to ROB entry

  UopType     uop\_type;    // determines which EU can accept this uop

  PhysReg     prs1, prs2;  // physical source registers

  PhysReg     prd;         // physical destination register

  Bool        prs1\_rdy;    // scoreboard snapshot at dispatch time

  Bool        prs2\_rdy;

  UopImm      imm;         // pre\-decoded, sign\-extended immediate

  FuSelect    fu\_sel;      // exact functional unit selector

  UopAge      age;         // logical age for age\-ordered issue

  Bool        is\_last;     // last uop of a MOP \(for MOP completion tracking\)

\} Uop deriving \(Bits\);

## __2\.3  Front\-End__

__Block__

__Parameters__

__Notes__

Fetch width

4 instructions/cycle

Aligned 16\-byte fetch window

Fetch buffer

8 entries

BSV FIFOF with custom drain

Branch predictor

TAGE\-SC\-L

State\-of\-the\-art; better than BOOM's TAGE alone on integer workloads

BTB \(L0\)

1\-cycle redirect

Direct\-mapped, very small, catches simple taken branches

BTB \(L1 dense\)

2\-cycle redirect

Larger, covers most indirect branches

TAGE\-SC\-L

3\-cycle redirect

Full predictor with statistical correction and loop predictor

Return Address Stack

16 entries

Accurate ret prediction

Decode width

2\-wide

Decode \+ crack to µOPs; feeds dispatch

Fetch → decode

FIFO decoupled

Fetch buffer absorbs front\-end bubbles

TAGE\-SC\-L rationale: the statistical correction \(SC\) component detects cases where the TAGE prediction is statistically biased and overrides it\. The loop predictor \(L\) handles counted loops exactly\. Together, these components recover 10–15% of the mispredictions that TAGE alone misses on SPEC INT and CoreMark workloads\.

## __2\.4  Register Rename__

__Parameter__

__Value__

__Notes__

Physical registers

96 \(int\) \+ 96 \(fp\)

64 architectural \+ 32 speculative in\-flight

Rename table

Vector\#\(96, Maybe\#\(ArchReg\)\)

BSV type; compiler enforces valid/invalid

Free list

FIFOF\#\(PhysReg\)

Pop on rename, push on commit/squash

Branch snapshots

8 entries

One per in\-flight branch; used for fast recovery

Recovery mechanism

Snapshot restore

Cheaper than walking the ROB; bounded recovery latency

BSV's Maybe\#\(PhysReg\) type encodes the valid bit structurally — the compiler refuses to use an invalid rename mapping without an explicit case match\. This eliminates an entire class of rename\-correctness bugs that manifest as silent wrong\-answer failures in Verilog designs\.

## __2\.5  Unified Age\-Ordered Issue Queue__

### __2\.5\.1  Design__

Diablo replaces BOOM's three split queues with a single unified age\-ordered issue queue\. This is the most architecturally significant departure from BOOM and directly addresses BOOM's priority\-starvation pathology\.

__Parameter__

__Value__

Entries

24

Dispatch width

2 µOPs/cycle

Issue width

up to 4 µOPs/cycle \(one per EU type\)

Ordering

Age\-ordered: older ready µOPs always selected over younger

FU filtering

Each select port filters by UopType tag

Wakeup

Broadcast: writeback tag compared against all src tags in parallel

Implementation

BSV Vector\#\(24, Maybe\#\(IssueSlot\)\) \+ tournament select tree rules

### __2\.5\.2  Age\-Ordered Select Tree__

Issue selection is implemented as a BSV rule that reduces a Vector of ready slots into the oldest\-ready µOP per EU type\. The tournament tree is a combinational function over the vector — BSV's scheduler ensures it fires atomically with the issue rules\.

function Maybe\#\(IssueSlot\) selectOldest\(Vector\#\(24, Maybe\#\(IssueSlot\)\) slots, UopType t\);

  // Filter to slots with matching UopType and prs1\_rdy && prs2\_rdy

  // Fold with: keep slot with lower age field

  return fold\(mergeOlder, map\(filterType\(t\), slots\)\);

endfunction

### __2\.5\.3  Wakeup Protocol__

On writeback, the completing µOP's physical destination register tag \(prd\) is broadcast on a RWire\. All 24 issue slots compare their prs1/prs2 tags against the broadcast in the same clock cycle\. BSV's RWire semantics guarantee the comparison happens in the same rule schedule as the writeback\.

- ALU writeback → fast wakeup → dependent µOP can issue next cycle
- Load / FP writeback → wakeup arrives from register file port → dependent µOP issues after writeback completes

## __2\.6  Reorder Buffer \(ROB\)__

__Parameter__

__Value__

__Notes__

Entries

64

Circular buffer; BSV Vector\#\(64, RobSlot\)

Commit width

2 µOPs/cycle

Per\-µOP commit \(simpler than per\-instruction\)

Head pointer

ROB head

Points to oldest in\-flight µOP

Tail pointer

ROB tail

Next free slot

Exception hold

pending\_exception Reg

Blocks commit; triggers flush on oldest excepting µOP

Branch tracking

in\-slot epoch tag

Epoch mismatch on writeback → squash younger µOPs

Store commit

on ROB head retire

Store data moved from store queue to cache at commit

Per\-µOP commit \(rather than per\-instruction\) simplifies the commit logic: the ROB does not need to track how many µOPs a given MOP cracked into during the commit walk\. The is\_last flag on each µOP marks the final µOP of a MOP, which is when the architectural register mapping is updated and the MOP is considered retired\.

## __2\.7  Execute Stage__

### __2\.7\.1  Execution Units__

__EU__

__Count__

__Functional Units__

__Latency__

__Wakeup Type__

Integer ALU / Branch

4

ALU \+ branch resolution

1 cycle

Fast \(RWire broadcast\)

Integer ALU / Jump

1

ALU \+ jump

1 cycle

Fast

Integer ALU / CSR

1

ALU \+ CSR r/w

serialising

Fast

Multiply

1

Pipelined multiplier

3 cycles

Fast \(fixed latency\)

Divide

1

Unpipelined divider

variable

Slow \(writeback\)

AGU \+ Load

2

Address gen → LQ

4\-cycle hit

Slow \(writeback\)

AGU \+ Store

1

Address gen → SQ

4\-cycle hit

Slow \(writeback\)

FPU

2

FP add/mul/cmp \+ FDiv

3–20 cycles

Slow \(writeback\)

### __2\.7\.2  Bypass Network in BSV__

Rather than an explicit bypass network module, Diablo uses BSV RWire and BypassWire primitives directly within the execute rules\. This means the bypass is expressed as a rule scheduling constraint rather than a manually wired multiplexer tree\.

RWire\#\(Tuple2\#\(PhysReg, Word64\)\) alu\_result\_wire\[4\] <\- replicateM\(mkRWire\);

// In the ALU execute rule:

alu\_result\_wire\[i\]\.wset\(tuple2\(uop\.prd, result\)\);

// In the register\-read / issue rule:

// Check all alu\_result\_wires before reading PRF

let src1 = fromMaybe\(prf\.read\(uop\.prs1\), bypassCheck\(alu\_result\_wire, uop\.prs1\)\);

The BSV compiler's rule scheduler guarantees that alu\_result\_wire\.wset and the bypassCheck read are in the same scheduling epoch, making the bypass semantics formally correct without explicit simulation\-time assertions\.

### __2\.7\.3  Branch Recovery__

Diablo uses per\-branch rename snapshots stored in a small snapshot array \(8 entries, one per in\-flight branch\)\. On mispredict:

- The branch unit writes the correct target to the fetch redirect RWire\.
- The ROB squash rule fires: all ROB entries younger than the mispredicted branch are invalidated\.
- The rename table is restored from the branch's snapshot entry\.
- The free list is rewound to the snapshot free\-list head\.
- The fetch unit redirects on the next cycle\.

End\-to\-end, this is a 3\-cycle recovery latency for the rename/issue pipeline portion, plus the front\-end redirect cycles\. The total effective mispredict penalty target is 8–10 cycles, compared to BOOMv3's 12\.

## __2\.8  Load/Store Unit__

__Structure__

__Entries__

__Notes__

Load Queue

16

Tracks in\-flight loads; detects memory ordering violations on late stores

Store Queue

12

Buffers stores; data committed to cache at ROB head retire

Store\-to\-load forward

—

Checked at load\-issue time; full address match forwarding

MSHRs

4

Start conservative; increase in later milestones

Next\-line prefetcher

—

Simple stride\-based; reduces cold\-miss penalty on sequential access

## __2\.9  Diablo v0\.1 vs\. BOOM — Design Comparison__

__Dimension__

__BOOMv3__

__Diablo v0\.1__

HDL

Chisel \(Scala\)

Bluespec BSV

Pipeline model

Explicit staged modules

Atomic rules \(event\-driven\)

Issue queues

3 split \(INT/FP/MEM\)

1 unified age\-ordered \(24 entries\)

Issue ordering

Unordered \(MIPS R10K style\)

Age\-ordered \(oldest\-ready wins\)

µOP granularity

~1:1 with RISC\-V

Two\-level \(MOP → crack → µOP\)

Physical registers

128 int \+ 128 fp

96 int \+ 96 fp

ROB entries

64

64

Branch predictor

TAGE

TAGE\-SC\-L

Mispredict penalty

12 cycles

8–10 cycles \(target\)

Load\-use penalty

4 cycles

4 cycles \(same; cache\-bound\)

Bypass network

Explicit module

BSV RWire/BypassWire in rules

Branch recovery

Snapshot \+ ROB flush

Per\-branch snapshot \(8 entries\)

Commit granularity

Per\-instruction

Per\-µOP

CSR generation

Manual

YAML\-driven \(Chromite approach\)

Cache hierarchy

L1 I$ \+ L1 D$ \+ L2

L1 I$ \+ L1 D$ \+ L2 \(from Flute\)

Verification

riscv\-tests \+ FireSim

Tandem Verification vs Spike \+ riscv\-tests

## __2\.10  Development Milestones__

__Milestone__

__Goal__

__Key Success Criteria__

M0 — Diablo Foundations

Finish Diablo RISC\-V OoO core

Passes riscv\-tests RV64I in Bluesim

M1 — ISA Compliance

Full RV64GC correctness

All riscv\-tests RV64GC pass; Tandem Verification clean

M2 — RTOS Boot

Boot FreeRTOS

FreeRTOS shell responsive in Verilator sim

M3 — CoreMark baseline

CoreMark ≥ 3\.0/MHz

Benchmark run on Verilator; performance profiled

M4 — Linux Boot

Boot Linux kernel

Buildroot Linux boots to shell

M5 — Performance target

CoreMark ≥ 4\.5/MHz

Competitive with BOOMv2; Dhrystone measured

M6 — iAPX 432 front\-end

Attach 432 decode to Diablo backend

432 decode \+ OoO execute; basic programs run

## __2\.11  Reference Implementations__

The following open\-source projects inform Diablo's design\. None are copied wholesale; each contributes specific lessons or reusable infrastructure components\.

__Project__

__What Diablo Takes From It__

BOOM \(riscv\-boom/riscv\-boom\)

Execute stage microarchitecture reference; issue queue design study; branch recovery patterns to improve upon

Flute \(bluespec/Flute\)

ISA decode types, AXI4 fabric, CLINT, PLIC, L1/L2 cache \+ MMU, Tandem Verification, Debug Module — all reused directly

Toooba \(bluespec/Toooba\)

OoO rule patterns in BSV; branch epoch tracking; store queue / load queue interaction; scheduling annotation examples

Chromite \(incoresemi/chromite\)

BSV parameterisation style; Python\-driven CSR generation \(CSR\-BOX\); YAML ISA configuration approach

RISCY\-OOO \(MIT\)

Academic reference for ROB\-based OoO in BSV; Toooba is derived from this

## __2\.12  Future Directions \(Post\-v0\.1\)__

- Superscalar decode width increase to 4\-wide once single\-issue pipeline is stable\.
- FP pipeline addition \(deferred to v0\.2 to keep initial scope manageable\)\.
- Multi\-core / cache coherence using the Flute WB\_L1\_L2 coherent infrastructure\.
- iAPX 432 front\-end: attach a 432 decode / capability\-check stage to the Diablo OoO backend, testing the thesis that the 432 ISA failed due to microarchitecture not ISA design\.
- CHERI capability integration: the 432 work naturally leads to CHERI\-style capability hardware research on top of the Diablo platform\.

*Diablo  ·  Technical Design Reference v0\.1\-DRAFT  ·  May 2026*

