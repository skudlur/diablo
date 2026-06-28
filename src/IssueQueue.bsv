package IssueQueue;

import Vector::*;
import DiabloTypes::*;

interface IssueQueue_IFC;
    // Dispatch port (Rename -> IQ)
    method Action dispatch(Uop in);
    method Bool notFull();
    
    // Wakeup broadcast (Execute -> IQ)
    // M0 uses a single wakeup port. Future versions will scale this.
    method Action wakeup(PhysReg prd);
    
    // Issue ports for different Execution Units
    method ActionValue#(Uop) issue_ALU();
    method ActionValue#(Uop) issue_MEM_AGU();
    method ActionValue#(Uop) issue_BRANCH();
    
    // Flush pipeline
    method Action flush();
endinterface

(* synthesize *)
module mkIssueQueue(IssueQueue_IFC);

    // The 24-entry unified queue array
    Vector#(24, Reg#(IssueSlot)) queue <- replicateM(mkReg(IssueSlot{valid: False, uop: ?}));
    
    // RWire for intra-cycle wakeup bypass. Allows instructions to issue the same 
    // cycle their dependencies are broadcasted over the wakeup network.
    RWire#(PhysReg) wakeupWire <- mkRWire();

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

    // Helper: Check readiness considering current cycle wakeups (RWire bypass)
    function Bool isReady(Uop u, Maybe#(PhysReg) broadcast_prd);
        // prs=0 is x0, which is always ready. 
        // Otherwise it's ready if previously marked ready OR currently being woken up
        Bool rdy1 = u.prs1 == 0 || u.prs1_rdy || (isValid(broadcast_prd) && fromMaybe(?, broadcast_prd) == u.prs1);
        Bool rdy2 = u.prs2 == 0 || u.prs2_rdy || (isValid(broadcast_prd) && fromMaybe(?, broadcast_prd) == u.prs2);
        return rdy1 && rdy2;
    endfunction

    // Tournament tree root function: Map-Reduce over the 24 entries
    function Maybe#(Tuple2#(UInt#(5), Uop)) findOldestReady(UopType targetType);
        Vector#(24, Maybe#(Tuple2#(UInt#(5), Uop))) candidates;
        let wkup = wakeupWire.wget();
        
        for (Integer i = 0; i < 24; i = i + 1) begin
            if (queue[i].valid && queue[i].uop.uop_type == targetType && isReady(queue[i].uop, wkup)) begin
                candidates[i] = tagged Valid tuple2(fromInteger(i), queue[i].uop);
            end else begin
                candidates[i] = tagged Invalid;
            end
        end
        return fold(pickOlder, candidates);
    endfunction

    // Determine if we have a free slot
    function Maybe#(UInt#(5)) findFreeSlot();
        Maybe#(UInt#(5)) res = tagged Invalid;
        // Prioritize lower indices just as a standard convention
        for (Integer i = 23; i >= 0; i = i - 1) begin
            if (!queue[i].valid) res = tagged Valid fromInteger(i);
        end
        return res;
    endfunction

    // Rule: Commit the wakeup state into registers at the end of the clock cycle
    rule update_wakeup_state (isValid(wakeupWire.wget()));
        let prd = fromMaybe(?, wakeupWire.wget());
        if (prd != 0) begin
            for (Integer i = 0; i < 24; i = i + 1) begin
                if (queue[i].valid) begin
                    let u = queue[i].uop;
                    if (u.prs1 == prd) u.prs1_rdy = True;
                    if (u.prs2 == prd) u.prs2_rdy = True;
                    queue[i] <= IssueSlot { valid: True, uop: u };
                end
            end
        end
    endrule

    // --- Interfaces ---

    method Bool notFull();
        return isValid(findFreeSlot());
    endmethod

    // Dispatch an instruction into the queue
    method Action dispatch(Uop in) if (isValid(findFreeSlot()));
        let idx = fromMaybe(?, findFreeSlot());
        
        // Immediate wakeup bypass check at dispatch time
        // E.g., if dispatching in the same cycle a dependency is completing
        let wkup = wakeupWire.wget();
        if (isValid(wkup)) begin
            let prd = fromMaybe(?, wkup);
            if (in.prs1 == prd && prd != 0) in.prs1_rdy = True;
            if (in.prs2 == prd && prd != 0) in.prs2_rdy = True;
        end
        
        queue[idx] <= IssueSlot { valid: True, uop: in };
    endmethod
    
    // Broadcast a wakeup tag
    method Action wakeup(PhysReg prd);
        wakeupWire.wset(prd);
    endmethod
    
    // Issue oldest-ready ALU
    method ActionValue#(Uop) issue_ALU() if (isValid(findOldestReady(ALU)));
        let res = fromMaybe(?, findOldestReady(ALU));
        let idx = tpl_1(res);
        queue[idx] <= IssueSlot { valid: False, uop: ? }; // Clear slot on issue
        return tpl_2(res);
    endmethod

    // Issue oldest-ready MEM (AGU)
    method ActionValue#(Uop) issue_MEM_AGU() if (isValid(findOldestReady(MEM_AGU)));
        let res = fromMaybe(?, findOldestReady(MEM_AGU));
        let idx = tpl_1(res);
        queue[idx] <= IssueSlot { valid: False, uop: ? };
        return tpl_2(res);
    endmethod
    
    // Issue oldest-ready BRANCH
    method ActionValue#(Uop) issue_BRANCH() if (isValid(findOldestReady(BRANCH)));
        let res = fromMaybe(?, findOldestReady(BRANCH));
        let idx = tpl_1(res);
        queue[idx] <= IssueSlot { valid: False, uop: ? };
        return tpl_2(res);
    endmethod

    // Flush on mispredict / exception
    method Action flush();
        for (Integer i = 0; i < 24; i = i + 1) begin
            queue[i] <= IssueSlot { valid: False, uop: ? };
        end
    endmethod

endmodule

endpackage
