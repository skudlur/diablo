package DiabloCore;

import DiabloTypes::*;
import FetchStage::*;
import DecodeStage::*;
import RenameStage::*;
import IssueQueue::*;
import ReorderBuffer::*;
import PhysicalRegisterFile::*;
import ExecutionUnit::*;

interface DiabloCore_IFC;
    method Action start(bit[63:0] pc);
endinterface

(* synthesize *)
module mkDiabloCore(DiabloCore_IFC);

    FetchStage_IFC         fetch  <- mkFetchStage;
    DecodeStage_IFC        decode <- mkDecodeStage;
    RenameStage_IFC        rename <- mkRenameStage;
    IssueQueue_IFC         iq     <- mkIssueQueue;
    ReorderBuffer_IFC      rob    <- mkReorderBuffer;
    PRF_IFC                prf    <- mkPRF;
    ALU_IFC                alu    <- mkALU;

    // -----------------------------------------------------------
    // Pipeline Rules
    // -----------------------------------------------------------

    // Stage 1: Fetch -> Decode
    rule fetch_to_decode (fetch.notEmpty());
        let f2d = fetch.first();
        fetch.deq();
        decode.enq(f2d);
    endrule

    // Stage 2: Decode -> Rename
    rule decode_to_rename (decode.notEmpty());
        let d2r = decode.first();
        decode.deq();
        rename.enq(d2r);
    endrule

    // Stage 3: Rename -> ROB Allocate & Issue Queue Dispatch
    rule rename_to_backend (rename.notEmpty() && rob.notFull() && iq.notFull());
        Uop u = rename.first();
        rename.deq();
        
        // Allocate ROB entry
        // Note: For full tracking, ARD and epoch are passed here. Stubbed for M0 basic wiring.
        let id <- rob.allocate(u.is_last, u.prd, 0, 0);
        
        // Attach the allocated ROB ID to the Uop
        u.mop_id = id;
        
        // Dispatch to Issue Queue
        iq.dispatch(u);
    endrule

    // Stage 4: Issue -> Execute
    rule issue_to_execute;
        // Grab the oldest ready ALU instruction
        let u <- iq.issue_ALU();
        
        // Read operands from the Physical Register File
        // (In a cycle where a write happens simultaneously, PRF/RWire handles bypass natively)
        let s1 = prf.read1(u.prs1);
        let s2 = prf.read2(u.prs2);
        
        alu.execute(u, s1, s2);
    endrule

    // Stage 5: Execute -> Writeback & Wakeup
    rule execute_writeback (alu.has_result());
        let res = alu.get_result();
        alu.deq_result();
        
        // 1. Write the result to the Physical Register File
        prf.write(res.prd, res.data);
        
        // 2. Broadcast the destination tag to the Issue Queue to wake up dependents
        iq.wakeup(res.prd);
        
        // 3. Mark the instruction as completed in the ROB
        rob.complete(res.mop_id, res.excepting);
    endrule

    // Stage 6: Commit -> Retire
    rule commit_retire (!rob.get_pending_exception());
        let r <- rob.commit();
        let ret1 = tpl_1(r);
        let ret2 = tpl_2(r);
        
        if (isValid(ret1)) begin
            let slot = fromMaybe(?, ret1);
            // In a full implementation, we lookup the current ARD mapping to find the old PRD to free.
            // rename.commitRegister(old_prd);
        end
        if (isValid(ret2)) begin
            let slot = fromMaybe(?, ret2);
            // rename.commitRegister(old_prd);
        end
    endrule
    
    // Exception / Flush Rule
    rule handle_exception (rob.get_pending_exception());
        // For M0, simply clear all pipeline state to recover
        fetch.redirect(0, 0); // Redirect fetch to exception handler PC
        decode.clear();
        rename.flush(0);
        iq.flush();
        rob.flush();
    endrule

    // --- Core Interface ---

    method Action start(bit[63:0] pc);
        fetch.start(pc);
    endmethod

endmodule

endpackage
