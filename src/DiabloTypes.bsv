package DiabloTypes;

// Diablo core data types and structures
// Extracted from the Microarchitecture Specification (MAS)

// Physical Register Index (96 Int + 96 FP requires 7 bits)
typedef bit [6:0] PhysReg;

// Micro-Op Types
typedef enum {
    UOP_ALU,
    UOP_BRANCH,
    UOP_JUMP,
    UOP_CSR,
    UOP_MUL,
    UOP_DIV,
    UOP_LOAD,
    UOP_STORE,
    UOP_FPU
} UopType deriving (Bits, Eq, FShow);

// Execution Unit Type for Issue Queue filtering
typedef enum {
    EU_ALU,
    EU_MUL,
    EU_DIV,
    EU_MEM,
    EU_FPU
} EUType deriving (Bits, Eq, FShow);

// Issue Queue Slot
typedef struct {
    UopType   uop_type;
    EUType    eu_type;
    PhysReg   prd;       // Physical destination register
    PhysReg   prs1;      // Physical source register 1
    PhysReg   prs2;      // Physical source register 2
    Bool      prs1_rdy;  // Source 1 ready flag
    Bool      prs2_rdy;  // Source 2 ready flag
    bit[63:0] imm;       // Immediate value
    bit[7:0]  age;       // Age for tournament selection
    bit[3:0]  epoch;     // Branch epoch tag
} IssueSlot deriving (Bits, Eq, FShow);

// Reorder Buffer (ROB) Slot
typedef struct {
    Bool      is_last;   // Marks the end of a Macro-Op (MOP)
    PhysReg   prd;       // Physical destination register to commit
    bit[4:0]  ard;       // Architectural destination register
    bit[3:0]  epoch;     // Branch epoch tag
    Bool      completed; // Set when writeback happens
    Bool      excepting; // Exception flagged
} RobSlot deriving (Bits, Eq, FShow);

endpackage
