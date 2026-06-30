package IssueQueue;

import FIFOF::*;
import Vector::*;
import DiabloTypes::*;

interface IssueQueue_IFC;
    // Dispatch port (Rename -> IQ)
    method Action dispatch(Uop in);
    method Bool notFull();
    
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

    // Helper: Select the older Uop (smaller age value is older)
    function Maybe#(Tuple2#(UInt#(5), Uop)) pickOlder(Maybe#(Tuple2#(UInt#(5), Uop)) a, Maybe#(Tuple2#(UInt#(5), Uop)) b);
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

    // Tournament tree root function
    function Maybe#(Tuple2#(UInt#(5), Uop)) findOldestReady(UopType targetType);
        Vector#(24, Maybe#(Tuple2#(UInt#(5), Uop))) candidates;
        
        for (Integer i = 0; i < 24; i = i + 1) begin
            // Also consider instructions that are waking up this cycle
            Bool is_woken1 = False;
            Bool is_woken2 = False;
            for (Integer w = 0; w < 4; w = w + 1) begin
                if (wakeup_wires[w] matches tagged Valid .prd) begin
                    if (queue[i].uop.prs1 == prd) is_woken1 = True;
                    if (queue[i].uop.prs2 == prd) is_woken2 = True;
                end
            end
            
            if (queue[i].valid && queue[i].uop.uop_type == targetType) begin
                // Check full readiness again including wire
                Bool r1 = queue[i].uop.prs1 == 0 || queue[i].uop.prs1_rdy || is_woken1;
                Bool r2 = queue[i].uop.prs2 == 0 || queue[i].uop.prs2_rdy || is_woken2;
                if (r1 && r2) begin
                    candidates[i] = tagged Valid tuple2(fromInteger(i), queue[i].uop);
                end else begin
                    candidates[i] = tagged Invalid;
                end
            end else begin
                candidates[i] = tagged Invalid;
            end
        end
        return fold(pickOlder, candidates);
    endfunction

    // Single Rule to update the queue state
    rule update_queue;
        IssueSlot new_queue[24];
        for (Integer i = 0; i < 24; i = i + 1) new_queue[i] = queue[i];
        
        if (flush_wire) begin
            for (Integer i = 0; i < 24; i = i + 1) new_queue[i].valid = False;
        end else begin
            // 1. Clear issued slots
            for (Integer i = 0; i < 24; i = i + 1) begin
                if (issued_wire[i]) new_queue[i].valid = False;
            end
            
            // 2. Apply wakeups
            for (Integer w = 0; w < 4; w = w + 1) begin
                if (wakeup_wires[w] matches tagged Valid .prd) begin
                    if (prd != 0) begin
                        for (Integer i = 0; i < 24; i = i + 1) begin
                            if (new_queue[i].valid) begin
                                if (new_queue[i].uop.prs1 == prd) new_queue[i].uop.prs1_rdy = True;
                                if (new_queue[i].uop.prs2 == prd) new_queue[i].uop.prs2_rdy = True;
                            end
                        end
                    end
                end
            end
            
            // 3. Apply dispatch
            if (dispatch_wire matches tagged Valid .u) begin
                Uop uop_mod = u;
                for (Integer w = 0; w < 4; w = w + 1) begin
                    if (wakeup_wires[w] matches tagged Valid .prd) begin
                        if (prd != 0) begin
                            if (uop_mod.prs1 == prd) uop_mod.prs1_rdy = True;
                            if (uop_mod.prs2 == prd) uop_mod.prs2_rdy = True;
                        end
                    end
                end
                Maybe#(UInt#(5)) free_slot = tagged Invalid;
                for (Integer i = 23; i >= 0; i = i - 1) begin
                    if (!new_queue[i].valid) free_slot = tagged Valid fromInteger(i);
                end
                if (free_slot matches tagged Valid .idx) begin
                    new_queue[idx] = IssueSlot { valid: True, uop: uop_mod };
                end
            end
        end
        
        for (Integer i = 0; i < 24; i = i + 1) begin
            queue[i] <= new_queue[i];
        end
        
        // Debug dump
        if (new_queue[0].valid) begin
            $display("IssueQueue Dump (cycle top):");
            for (Integer i = 0; i < 24; i = i + 1) begin
                if (new_queue[i].valid) begin
                    $display("  IQ[%0d]: pc=%x, type=%d, prs1=%0d (rdy=%b), prs2=%0d (rdy=%b), prd=%0d", 
                             i, new_queue[i].uop.pc, new_queue[i].uop.uop_type, new_queue[i].uop.prs1, new_queue[i].uop.prs1_rdy, new_queue[i].uop.prs2, new_queue[i].uop.prs2_rdy, new_queue[i].uop.prd);
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
    
    method Action wakeup1(PhysReg prd); wakeup_wires[0] <= tagged Valid prd; endmethod
    method Action wakeup2(PhysReg prd); wakeup_wires[1] <= tagged Valid prd; endmethod
    method Action wakeup3(PhysReg prd); wakeup_wires[2] <= tagged Valid prd; endmethod
    method Action wakeup4(PhysReg prd); wakeup_wires[3] <= tagged Valid prd; endmethod
    
    method Bool has_ready_ALU();
        return isValid(findOldestReady(ALU));
    endmethod
    method ActionValue#(Uop) issue_ALU() if (isValid(findOldestReady(ALU)));
        let res = fromMaybe(?, findOldestReady(ALU));
        let idx = tpl_1(res);
        issued_wire[idx] <= True;
        return tpl_2(res);
    endmethod

    method Bool has_ready_MEM_AGU();
        return isValid(findOldestReady(MEM_AGU));
    endmethod
    method ActionValue#(Uop) issue_MEM_AGU() if (isValid(findOldestReady(MEM_AGU)));
        let res = fromMaybe(?, findOldestReady(MEM_AGU));
        let idx = tpl_1(res);
        issued_wire[idx] <= True;
        return tpl_2(res);
    endmethod
    
    method Bool has_ready_BRANCH();
        return isValid(findOldestReady(BRANCH));
    endmethod
    method ActionValue#(Uop) issue_BRANCH() if (isValid(findOldestReady(BRANCH)));
        let res = fromMaybe(?, findOldestReady(BRANCH));
        let idx = tpl_1(res);
        issued_wire[idx] <= True;
        return tpl_2(res);
    endmethod

    method Bool has_ready_MULT();
        return isValid(findOldestReady(MULT));
    endmethod
    method ActionValue#(Uop) issue_MULT() if (isValid(findOldestReady(MULT)));
        let res = fromMaybe(?, findOldestReady(MULT));
        let idx = tpl_1(res);
        issued_wire[idx] <= True;
        return tpl_2(res);
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
