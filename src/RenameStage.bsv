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
    
    // Retire / Commit signal
    method Action commitRegister(PhysReg old_prd);
    
    // Flush & Recovery
    method Action flush(bit[3:0] mispredict_epoch);
    method Action resolve_correct_branch();
    
    // Scoreboard wakeup
    method Action wakeup(PhysReg prd);
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
    
    // BusyTable: Tracks if a physical register is currently being computed
    Vector#(96, Reg#(Bool)) busyTable <- replicateM(mkReg(False));
    
    // Wakeup Wire from Execute Writeback
    Wire#(Maybe#(PhysReg)) wakeup_wire <- mkDWire(tagged Invalid);
    
    // Commit wire
    Wire#(Maybe#(PhysReg)) commit_wire <- mkDWire(tagged Invalid);
    
    Reg#(Bool) initialized <- mkReg(False);
    Reg#(PhysReg) init_counter <- mkReg(64); 
    
    Reg#(Bool) stall_on_branch <- mkReg(False);
    
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
    rule do_rename (initialized && inQ.notEmpty() && freeList.notEmpty() && outQ.notFull() && !stall_on_branch);
        let d = inQ.first();
        inQ.deq();
        
        // Read sources from the current rename table
        PhysReg p_src1 = renameTable[d.src1];
        PhysReg p_src2 = renameTable[d.src2];
        
        // Capture old mapping before overwriting (for freeing at commit)
        PhysReg old_dst = renameTable[d.dst];
        
        // Allocate destination (Except for x0 which always maps to p0 and is never renamed)
        PhysReg p_dst = 0;
        if (d.dst != 0) begin
            p_dst = freeList.first();
            freeList.deq();
            renameTable[d.dst] <= p_dst;
            busyTable[p_dst] <= True; // Mark as busy until writeback
        end else begin
            old_dst = 0; // x0 has no old mapping to free
        end
        
        // Create the Uop for the backend
        Bool rdy1 = !busyTable[p_src1];
        Bool rdy2 = !busyTable[p_src2];
        
        // Snooping wakeup from this cycle
        if (wakeup_wire matches tagged Valid .prd) begin
            if (p_src1 == prd) rdy1 = True;
            if (p_src2 == prd) rdy2 = True;
        end
        
        Uop out_uop = Uop {
            mop_id:   0,       // M0 stub: Will be allocated by ROB
            pc:       d.pc,
            pred_pc:  d.pred_pc,
            uop_type: d.uop_type,
            prs1:     p_src1,
            prs2:     p_src2,
            prd:      p_dst,
            old_prd:  old_dst,
            prs1_rdy: rdy1,
            prs2_rdy: rdy2,
            imm:      d.imm,
            fu_sel:   d.fu_sel,
            age:      0,       // M0 stub: Assigned at Issue queue entry
            mem_size: d.mem_size,
            is_store: d.is_store,
            is_last:  d.is_last
        };
        
        if (d.uop_type == BRANCH) begin
            stall_on_branch <= True;
        end

        
        // //$display("RenameStage: Renamed PC = %x", d.pc);
        outQ.enq(out_uop);
    endrule
    
    rule process_wakeup;
        if (wakeup_wire matches tagged Valid .prd) begin
            if (prd != 0) begin
                busyTable[prd] <= False;
            end
        end
    endrule

    rule debug_status (initialized);
        // //$display("RenameStage Status: init=%b, inQ_notEmpty=%b, freeList_notEmpty=%b, outQ_notFull=%b, outQ_notEmpty=%b", 
        //          initialized, inQ.notEmpty(), freeList.notEmpty(), outQ.notFull(), outQ.notEmpty());
    endrule
    
    // Rule to process commit frees
    rule do_commit_free (initialized);
        if (commit_wire matches tagged Valid .prd) begin
            if (prd != 0) freeList.enq(prd);
        end
    endrule
    
    Wire#(Bool) resolve_branch_wire <- mkDWire(False);
    
    rule process_resolve_branch (resolve_branch_wire);
        stall_on_branch <= False;
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
        commit_wire <= tagged Valid old_prd;
    endmethod
    
    method Action flush(bit[3:0] mispredict_epoch);
        // M0 Stub: In a real core, we restore the rename table from a snapshot
        inQ.clear();
        outQ.clear();
        stall_on_branch <= False;
    endmethod
    
    method Action resolve_correct_branch();
        resolve_branch_wire <= True;
    endmethod
    
    method Action wakeup(PhysReg prd);
        wakeup_wire <= tagged Valid prd;
    endmethod

endmodule

endpackage
