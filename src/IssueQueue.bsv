package IssueQueue;

import FIFOF::*;
import Vector::*;
import DiabloTypes::*;

interface IssueQueue_IFC;
    // Dispatch port (Rename -> IQ)
    method Action dispatch(Uop in);
    method Bool notFull();
    
    // Serialization Support
    method Action set_rob_head(MopId id);
    
    // Wakeup broadcast (Execute -> IQ)
    method Action wakeup1(PhysReg prd);
    method Action wakeup2(PhysReg prd);
    method Action wakeup3(PhysReg prd);
    method Action wakeup4(PhysReg prd);
    
    // Issue ports for different Execution Units
    method Bool has_ready_ALU();
    method ActionValue#(Uop) issue_ALU();
    
    method Bool has_ready_MEM_AGU();
    method ActionValue#(Uop) issue_MEM_AGU();
    
    method Bool has_ready_BRANCH();
    method ActionValue#(Uop) issue_BRANCH();
    
    method Bool has_ready_MULT();
    method ActionValue#(Uop) issue_MULT();
    
    // Flush pipeline
    method Action flush();
    
    // Debug
    method Action dump();
endinterface

(* synthesize *)
module mkIssueQueue(IssueQueue_IFC);

    Vector#(24, Reg#(IssueSlot)) queue <- replicateM(mkReg(IssueSlot{valid: False, uop: ?}));
    
    // Decoupling Wires
    Wire#(Maybe#(Uop)) dispatch_wire <- mkDWire(tagged Invalid);
    Vector#(4, Wire#(Maybe#(PhysReg))) wakeup_wires <- replicateM(mkDWire(tagged Invalid));
    Vector#(24, Wire#(Bool)) issued_wire <- replicateM(mkDWire(False));
    Wire#(Bool) flush_wire <- mkDWire(False);
    Wire#(MopId) rob_head_wire <- mkDWire(0);
    
    Wire#(Maybe#(UInt#(6))) ready_alu <- mkDWire(tagged Invalid);
    Wire#(Maybe#(UInt#(6))) ready_agu <- mkDWire(tagged Invalid);
    Wire#(Maybe#(UInt#(6))) ready_bru <- mkDWire(tagged Invalid);
    Wire#(Maybe#(UInt#(6))) ready_mult <- mkDWire(tagged Invalid);

    // Helper: Select the older Uop (smaller age value is older)
    function Maybe#(Tuple2#(UInt#(6), Uop)) pickOlder(Maybe#(Tuple2#(UInt#(6), Uop)) a, Maybe#(Tuple2#(UInt#(6), Uop)) b);
        if (isValid(a) && isValid(b)) begin
            let val_a = fromMaybe(?, a);
            let val_b = fromMaybe(?, b);
            if (tpl_2(val_a).age <= tpl_2(val_b).age) return a;
            else return b;
        end else if (isValid(a)) begin
            return a;
        end else begin
            return b;
        end
    endfunction

    // Helper: Check readiness
    function Bool isReady(Uop u);
        Bool rdy1 = u.prs1 == 0 || u.prs1_rdy;
        Bool rdy2 = u.prs2 == 0 || u.prs2_rdy;
        return rdy1 && rdy2;
    endfunction

    // Tournament tree root function (implemented as a fold tree to avoid memory explosion)
    function Maybe#(UInt#(6)) findOldestReady(UopType targetType);
        Vector#(32, Maybe#(Tuple2#(UInt#(6), Uop))) candidates = replicate(tagged Invalid);
        
        for (Integer i = 0; i < 24; i = i + 1) begin
            if (queue[i].valid && queue[i].uop.uop_type == targetType) begin
                Bool r1 = queue[i].uop.prs1 == 0 || queue[i].uop.prs1_rdy;
                Bool r2 = queue[i].uop.prs2 == 0 || queue[i].uop.prs2_rdy;
                Bool is_head = (queue[i].uop.mop_id == rob_head_wire);
                
                if (r1 && r2 && (!queue[i].uop.is_serialize || is_head)) begin
                    candidates[i] = tagged Valid tuple2(fromInteger(i), queue[i].uop);
                end
            end
        end
        
        let oldest = fold(pickOlder, candidates);
        if (oldest matches tagged Valid .val) begin
            return tagged Valid tpl_1(val);
        end else begin
            return tagged Invalid;
        end
    endfunction
    
    rule compute_ready;
        ready_alu <= findOldestReady(ALU);
        ready_agu <= findOldestReady(MEM_AGU);
        ready_bru <= findOldestReady(BRANCH);
        ready_mult <= findOldestReady(MULT);
    endrule
    
    // Single Rule to update the queue state
    rule update_queue;
        // Find a free slot for dispatch
        Maybe#(UInt#(6)) free_slot = tagged Invalid;
        for (Integer i = 23; i >= 0; i = i - 1) begin
            if (!queue[i].valid && !issued_wire[i]) free_slot = tagged Valid fromInteger(i);
        end
        
        // Prepare dispatched uop
        Uop dispatched_uop = ?;
        Bool do_dispatch = False;
        if (dispatch_wire matches tagged Valid .u) begin
            do_dispatch = True;
            dispatched_uop = u;
            for (Integer w = 0; w < 4; w = w + 1) begin
                if (wakeup_wires[w] matches tagged Valid .prd) begin
                    if (prd != 0) begin
                        if (dispatched_uop.prs1 == prd) dispatched_uop.prs1_rdy = True;
                        if (dispatched_uop.prs2 == prd) dispatched_uop.prs2_rdy = True;
                    end
                end
            end
        end
        
        for (Integer i = 0; i < 24; i = i + 1) begin
            IssueSlot slot = queue[i];
            
            if (flush_wire) begin
                slot.valid = False;
            end else begin
                // 1. Clear issued slots
                if (issued_wire[i]) slot.valid = False;
                
                // 2. Apply wakeups
                for (Integer w = 0; w < 4; w = w + 1) begin
                    if (wakeup_wires[w] matches tagged Valid .prd) begin
                        if (prd != 0 && slot.valid) begin
                            if (slot.uop.prs1 == prd) slot.uop.prs1_rdy = True;
                            if (slot.uop.prs2 == prd) slot.uop.prs2_rdy = True;
                        end
                    end
                end
                
                // 3. Apply dispatch
                if (do_dispatch &&& free_slot matches tagged Valid .idx &&& idx == fromInteger(i)) begin
                    slot = IssueSlot { valid: True, uop: dispatched_uop };
                end
            end
            
            queue[i] <= slot;
        end
        
        // Debug dump
        if (queue[0].valid) begin
            $display("IssueQueue Dump (cycle top): has_ready_ALU=%b", isValid(ready_alu));
            for (Integer i = 0; i < 7; i = i + 1) begin
                if (queue[i].valid) begin
                    $display("  IQ[%0d]: pc=%x, type=%d, prs1=%0d (rdy=%b), prs2=%0d (rdy=%b), prd=%0d", 
                             i, queue[i].uop.pc, queue[i].uop.uop_type, queue[i].uop.prs1, queue[i].uop.prs1_rdy, queue[i].uop.prs2, queue[i].uop.prs2_rdy, queue[i].uop.prd);
                end
            end
        end
    endrule

    // --- Interfaces ---

    method Bool notFull();
        Bool has_free = False;
        for (Integer i = 0; i < 24; i = i + 1) begin
            if (!queue[i].valid) has_free = True;
        end
        return has_free;
    endmethod

    method Action dispatch(Uop in);
        dispatch_wire <= tagged Valid in;
    endmethod
    
    method Action set_rob_head(MopId id);
        rob_head_wire <= id;
    endmethod
    
    method Action wakeup1(PhysReg prd); wakeup_wires[0] <= tagged Valid prd; endmethod
    method Action wakeup2(PhysReg prd); wakeup_wires[1] <= tagged Valid prd; endmethod
    method Action wakeup3(PhysReg prd); wakeup_wires[2] <= tagged Valid prd; endmethod
    method Action wakeup4(PhysReg prd); wakeup_wires[3] <= tagged Valid prd; endmethod
    
    method Bool has_ready_ALU();
        return isValid(ready_alu);
    endmethod
    method ActionValue#(Uop) issue_ALU() if (isValid(ready_alu));
        let idx = fromMaybe(?, ready_alu);
        issued_wire[idx] <= True;
        return queue[idx].uop;
    endmethod

    method Bool has_ready_MEM_AGU();
        return isValid(ready_agu);
    endmethod
    method ActionValue#(Uop) issue_MEM_AGU() if (isValid(ready_agu));
        let idx = fromMaybe(?, ready_agu);
        issued_wire[idx] <= True;
        return queue[idx].uop;
    endmethod
    
    method Bool has_ready_BRANCH();
        return isValid(ready_bru);
    endmethod
    method ActionValue#(Uop) issue_BRANCH() if (isValid(ready_bru));
        let idx = fromMaybe(?, ready_bru);
        issued_wire[idx] <= True;
        return queue[idx].uop;
    endmethod

    method Bool has_ready_MULT();
        return isValid(ready_mult);
    endmethod
    method ActionValue#(Uop) issue_MULT() if (isValid(ready_mult));
        let idx = fromMaybe(?, ready_mult);
        issued_wire[idx] <= True;
        return queue[idx].uop;
    endmethod

    method Action flush();
        flush_wire <= True;
    endmethod
    
    method Action dump();
        for (Integer i = 0; i < 24; i = i + 1) begin
            if (queue[i].valid) begin
                $display("  IQ[%0d]: pc=%x, type=%d, prs1=%0d (rdy=%b), prs2=%0d (rdy=%b), prd=%0d", 
                         i, queue[i].uop.pc, queue[i].uop.uop_type, queue[i].uop.prs1, queue[i].uop.prs1_rdy, queue[i].uop.prs2, queue[i].uop.prs2_rdy, queue[i].uop.prd);
            end
        end
    endmethod

endmodule

endpackage
