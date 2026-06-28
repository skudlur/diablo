package RenameStage;

import FIFOF::*;
import SpecialFIFOs::*;
import Vector::*;
import DiabloTypes::*;
import DecodeStage::*;

interface RenameStage_IFC;
    // Input from Decode
    method Action enq(Decode2Rename in);
    
    // Output to Issue Queue / ROB allocator
    method Uop first();
    method Action deq();
    method Bool notEmpty();
    
    // Retire / Commit signals
    method Action commitRegister(PhysReg old_prd);
    
    // Flush & Recovery
    method Action flush(bit[3:0] mispredict_epoch);
endinterface

// Basic M0 Rename Stage module
(* synthesize *)
module mkRenameStage(RenameStage_IFC);

    // Pipeline queues
    FIFOF#(Decode2Rename) inQ <- mkFIFOF;
    FIFOF#(Uop) outQ <- mkFIFOF;
    
    // Rename Table: 64 Architectural Registers mapping to PhysReg
    // 0-31 = Integer Regs, 32-63 = FP Regs
    Vector#(64, Reg#(PhysReg)) renameTable <- replicateM(mkReg(0));
    
    // Free List: Holds unused physical registers. Total 192 (96 Int + 96 FP, though we mapped 1-192)
    // We'll use 96 total for simplicity in M0 (0-95).
    // ArchReg 0-63 map to PhysReg 0-63 at reset. PhysReg 64-95 go to the free list.
    FIFOF#(PhysReg) freeList <- mkSizedFIFOF(96);
    
    Reg#(Bool) initialized <- mkReg(False);
    Reg#(PhysReg) init_counter <- mkReg(64); 
    
    // Initialize the free list and base rename table
    rule do_initialize (!initialized);
        if (init_counter < 96) begin
            freeList.enq(init_counter);
            init_counter <= init_counter + 1;
        end else begin
            initialized <= True;
        end
    endrule

    // Main Rename rule
    rule do_rename (initialized && inQ.notEmpty() && freeList.notEmpty() && outQ.notFull());
        let d = inQ.first();
        inQ.deq();
        
        // Read sources from the current rename table
        PhysReg p_src1 = renameTable[d.src1];
        PhysReg p_src2 = renameTable[d.src2];
        
        // Allocate destination (Except for x0 which always maps to p0 and is never renamed)
        PhysReg p_dst = 0;
        if (d.dst != 0) begin
            p_dst = freeList.first();
            freeList.deq();
            renameTable[d.dst] <= p_dst;
            
            // Note: In a full implementation, we'd also store a snapshot here for branches
        end
        
        // Create the Uop for the backend
        Uop out_uop = Uop {
            mop_id:   0,       // M0 stub: Will be allocated by ROB
            uop_type: d.uop_type,
            prs1:     p_src1,
            prs2:     p_src2,
            prd:      p_dst,
            prs1_rdy: False,   // M0 stub: Will be checked against scoreboard
            prs2_rdy: False,   // M0 stub: Will be checked against scoreboard
            imm:      d.imm,
            fu_sel:   d.fu_sel,
            age:      0,       // M0 stub: Assigned at Issue queue entry
            is_last:  d.is_last
        };
        
        outQ.enq(out_uop);
    endrule
    
    // --- Interfaces ---

    method Action enq(Decode2Rename in) if (initialized && inQ.notFull());
        inQ.enq(in);
    endmethod

    method Uop first() if (outQ.notEmpty());
        return outQ.first();
    endmethod

    method Action deq() if (outQ.notEmpty());
        outQ.deq();
    endmethod

    method Bool notEmpty();
        return outQ.notEmpty();
    endmethod
    
    method Action commitRegister(PhysReg old_prd);
        // When an instruction commits, its previous physical destination mapping is freed
        if (old_prd != 0) begin
            freeList.enq(old_prd);
        end
    endmethod
    
    method Action flush(bit[3:0] mispredict_epoch);
        inQ.clear();
        outQ.clear();
        // M0 stub: A full flush would also restore the rename table from the branch snapshot array
    endmethod

endmodule

endpackage
