package FetchStage;

import FIFOF::*;
import SpecialFIFOs::*;
import DiabloTypes::*;

// Struct representing the bundle of data sent from Fetch to Decode
typedef struct {
    bit[63:0] pc;
    bit[31:0] inst; // 32-bit instruction
    bit[3:0]  epoch; // Branch prediction epoch
} Fetch2Decode deriving (Bits, Eq, FShow);

interface FetchStage_IFC;
    // Core pipeline control
    method Action start(bit[63:0] start_pc);
    method Action redirect(bit[63:0] new_pc, bit[3:0] new_epoch);
    
    // Output to Decode stage
    method Fetch2Decode first();
    method Action deq();
    method Bool notEmpty();
    
    // (Future: IMem / ITLB interfaces will go here)
endinterface

// Simple M0 Fetch Stage module
(* synthesize *)
module mkFetchStage(FetchStage_IFC);

    // Fetch Buffer: 8-entry FIFOF
    FIFOF#(Fetch2Decode) fBuffer <- mkSizedFIFOF(8);
    
    // Architectural state
    Reg#(bit[63:0]) pc_reg <- mkReg(0);
    Reg#(bit[3:0])  epoch_reg <- mkReg(0);
    Reg#(Bool)      active <- mkReg(False);

    // Mock instruction memory - returns NOPs for now
    // In later phases, this will connect to Flute's ICache
    function bit[31:0] mock_imem(bit[63:0] addr);
        // Return RISC-V NOP (ADDI x0, x0, 0) : 0x00000013
        return 32'h00000013;
    endfunction

    // Rule: Fetch an instruction and push to buffer
    rule do_fetch (active && fBuffer.notFull());
        bit[31:0] inst = mock_imem(pc_reg);
        
        fBuffer.enq(Fetch2Decode {
            pc: pc_reg,
            inst: inst,
            epoch: epoch_reg
        });
        
        // Next PC (assuming 4-byte aligned instructions for now)
        pc_reg <= pc_reg + 4;
    endrule

    method Action start(bit[63:0] start_pc) if (!active);
        pc_reg <= start_pc;
        active <= True;
    endmethod

    method Action redirect(bit[63:0] new_pc, bit[3:0] new_epoch);
        pc_reg <= new_pc;
        epoch_reg <= new_epoch;
        fBuffer.clear(); // Flush the fetch buffer on redirect
    endmethod
    
    // Expose the fetch buffer's read side directly to decode
    method Fetch2Decode first() if (fBuffer.notEmpty());
        return fBuffer.first();
    endmethod
    
    method Action deq() if (fBuffer.notEmpty());
        fBuffer.deq();
    endmethod
    
    method Bool notEmpty();
        return fBuffer.notEmpty();
    endmethod

endmodule

endpackage
