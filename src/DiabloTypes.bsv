package DiabloTypes;

// Diablo core data types and structures
// Based on the Diablo v0.1 Design Reference

// ----------------------------------------------------------------
// Register Specifiers
// ----------------------------------------------------------------

// 64 Architectural Registers (32 Int + 32 FP)
typedef bit [5:0] ArchReg;

// 192 Physical Registers (96 Int + 96 FP requires 8 bits to index fully, or just 7 bits if split. 
// Since 96 + 96 = 192, we need 8 bits for a unified PhysReg index).
typedef bit [7:0] PhysReg;

// ----------------------------------------------------------------
// Micro-Op (uOP) and Execution Types
// ----------------------------------------------------------------

// Execution Unit Type filtering for the unified issue queue
typedef enum { 
    ALU, 
    MEM_AGU, 
    MEM_LS, 
    BRANCH, 
    MULT,
    FP, 
    SYS, 
    ROCC 
} UopType deriving (Bits, Eq, FShow);

// ROB Index - 64 entries
typedef bit [5:0] MopId;

// Immediate Value
typedef bit [63:0] UopImm;

// Functional Unit specific selector (e.g. ADD vs SUB vs XOR)
typedef bit [5:0] FuSelect;

// Age tag for the oldest-ready tournament selector
typedef bit [7:0] UopAge;

// The MicroOp structure dispatched to the Issue Queue
typedef struct {
    MopId       mop_id;      // Links back to ROB entry
    bit[63:0]   pc;          // Program Counter for branches/exceptions
    bit[63:0]   pred_pc;     // Predicted next PC from FetchStage
    UopType     uop_type;    // Determines which EU can accept this uop
    PhysReg     prs1;        // Physical source register 1
    PhysReg     prs2;        // Physical source register 2
    PhysReg     prd;         // Physical destination register
    PhysReg     old_prd;     // Previous physical destination (for ROB to free at commit)
    Bool        prs1_rdy;    // Scoreboard snapshot at dispatch time
    Bool        prs2_rdy;    // Scoreboard snapshot at dispatch time
    UopImm      imm;         // Pre-decoded, sign-extended immediate
    FuSelect    fu_sel;      // Exact functional unit selector
    UopAge      age;         // Logical age for age-ordered issue
    bit[2:0]    mem_size;
    Bool        is_store;
    Bool        is_last;     // Marks the last uop of a MOP (triggers commit)
} Uop deriving (Bits, Eq, FShow);

// ----------------------------------------------------------------
// Issue & Reorder Buffer Types
// ----------------------------------------------------------------

// Unified Age-Ordered Issue Queue Slot (24 entries)
typedef struct {
    Bool      valid;
    Uop       uop;
} IssueSlot deriving (Bits, Eq, FShow);

// Reorder Buffer (ROB) Slot (64 entries)
typedef struct {
    Bool      is_last;       // Marks the final uOP of an architectural instruction
    PhysReg   prd;           // Physical destination register mapped for this instruction
    PhysReg   old_prd;       // Previous physical register mapped to ard (freed at commit)
    ArchReg   ard;           // Architectural destination register to update on commit
    bit[3:0]  epoch;         // Branch tracking epoch tag
    Bool      completed;     // Set when writeback happens
    Bool      excepting;     // Set if an exception occurred during execution
} RobSlot deriving (Bits, Eq, FShow);

endpackage
