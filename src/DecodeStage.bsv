package DecodeStage;

import FIFOF::*;
import SpecialFIFOs::*;
import DiabloTypes::*;
import FetchStage::*;

// Struct representing the bundle of data sent from Decode to Rename
typedef struct {
    bit[63:0] pc;
    UopType   uop_type;
    ArchReg   src1;
    ArchReg   src2;
    ArchReg   dst;
    UopImm    imm;
    FuSelect  fu_sel;
    bit[3:0]  epoch;
    Bool      is_last;
} Decode2Rename deriving (Bits, Eq, FShow);

interface DecodeStage_IFC;
    // Input from Fetch stage
    method Action enq(Fetch2Decode in);
    
    // Output to Rename stage
    method Decode2Rename first();
    method Action deq();
    method Bool notEmpty();
    
    // Control
    method Action clear();
endinterface

// Basic M0 Decode Stage module
(* synthesize *)
module mkDecodeStage(DecodeStage_IFC);

    // Queue for Fetch -> Decode
    FIFOF#(Fetch2Decode) inQ <- mkFIFOF;
    
    // Queue for Decode -> Rename
    FIFOF#(Decode2Rename) outQ <- mkFIFOF;

    // Simple decode rule for M0
    // (A real implementation will use Flute's fv_decode here)
    rule do_decode;
        let f = inQ.first();
        inQ.deq();
        
        // Basic extraction for a typical R/I-type instruction
        // opcode = f.inst[6:0]
        // rd     = f.inst[11:7]
        // rs1    = f.inst[19:15]
        // rs2    = f.inst[24:20]
        
        // Prepending 0 to make it a 6-bit ArchReg (integer register)
        ArchReg rd_arch  = {1'b0, f.inst[11:7]}; 
        ArchReg rs1_arch = {1'b0, f.inst[19:15]};
        ArchReg rs2_arch = {1'b0, f.inst[24:20]};
        
        UopType uType = ALU;
        Bool last = True; // M0 assumes 1 MOP = 1 uOP for now
        
        outQ.enq(Decode2Rename {
            pc: f.pc,
            uop_type: uType,
            src1: rs1_arch,
            src2: rs2_arch,
            dst: rd_arch,
            imm: signExtend(f.inst[31:20]), // Simple I-type immediate
            fu_sel: 0,
            epoch: f.epoch,
            is_last: last
        });
    endrule

    method Action enq(Fetch2Decode in) if (inQ.notFull());
        inQ.enq(in);
    endmethod

    method Decode2Rename first() if (outQ.notEmpty());
        return outQ.first();
    endmethod

    method Action deq() if (outQ.notEmpty());
        outQ.deq();
    endmethod

    method Bool notEmpty();
        return outQ.notEmpty();
    endmethod
    
    method Action clear();
        inQ.clear();
        outQ.clear();
    endmethod

endmodule

endpackage
