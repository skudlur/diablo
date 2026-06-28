package ReorderBuffer;

import Vector::*;
import DiabloTypes::*;

interface ReorderBuffer_IFC;
    // Dispatch (Allocate) - from Rename stage
    // Returns the allocated MopId (ROB index) to be attached to the Uop
    method ActionValue#(MopId) allocate(Bool is_last, PhysReg prd, ArchReg ard, bit[3:0] epoch);
    method Bool notFull();
    
    // Writeback (Complete) - from Execute stage
    method Action complete(MopId id, Bool excepting);
    
    // Commit (Retire) - to Architectural state / Free List
    // We retire up to 2 uOPs per cycle. The method returns the retired slots
    // so the Rename stage can free the OLD physical registers, and the Commit stage
    // can update the architectural state if is_last is true.
    method ActionValue#(Tuple2#(Maybe#(RobSlot), Maybe#(RobSlot))) commit();
    
    // Exception / Flush
    method Bool get_pending_exception();
    method Action flush();
endinterface

(* synthesize *)
module mkReorderBuffer(ReorderBuffer_IFC);

    // 64-entry circular buffer
    Vector#(64, Reg#(RobSlot)) rob <- replicateM(mkReg(RobSlot{
        is_last: False, prd: 0, ard: 0, epoch: 0, completed: False, excepting: False
    }));
    
    // Head points to oldest entry, Tail points to next free slot
    Reg#(UInt#(6)) head <- mkReg(0);
    Reg#(UInt#(6)) tail <- mkReg(0);
    
    // Counter to distinguish between full and empty
    Reg#(UInt#(7)) count <- mkReg(0);
    
    // Blocks commit and triggers the flush/recovery state machine
    Reg#(Bool) pending_exception <- mkReg(False);

    // --- Interfaces ---

    method Bool notFull();
        return (count < 64);
    endmethod

    method ActionValue#(MopId) allocate(Bool is_last, PhysReg prd, ArchReg ard, bit[3:0] epoch) if (count < 64);
        MopId id = pack(tail);
        
        rob[tail] <= RobSlot {
            is_last:   is_last,
            prd:       prd,
            ard:       ard,
            epoch:     epoch,
            completed: False,
            excepting: False
        };
        
        tail <= (tail == 63) ? 0 : tail + 1;
        count <= count + 1;
        
        return id;
    endmethod
    
    method Action complete(MopId id, Bool excepting);
        UInt#(6) idx = unpack(id);
        let slot = rob[idx];
        slot.completed = True;
        slot.excepting = excepting;
        rob[idx] <= slot;
    endmethod
    
    // Commits up to 2 uOPs per cycle
    method ActionValue#(Tuple2#(Maybe#(RobSlot), Maybe#(RobSlot))) commit() if (count > 0 && !pending_exception);
        Maybe#(RobSlot) ret1 = tagged Invalid;
        Maybe#(RobSlot) ret2 = tagged Invalid;
        
        UInt#(6) next_head = head;
        UInt#(7) next_count = count;
        Bool triggered_exception = False;
        
        // Attempt to commit slot 1
        if (next_count > 0) begin
            let slot1 = rob[next_head];
            if (slot1.completed) begin
                if (slot1.excepting) begin
                    triggered_exception = True;
                end else begin
                    ret1 = tagged Valid slot1;
                    next_head = (next_head == 63) ? 0 : next_head + 1;
                    next_count = next_count - 1;
                    
                    // Attempt to commit slot 2 if slot 1 succeeded
                    if (next_count > 0) begin
                        let slot2 = rob[next_head];
                        if (slot2.completed) begin
                            if (slot2.excepting) begin
                                triggered_exception = True;
                            end else begin
                                ret2 = tagged Valid slot2;
                                next_head = (next_head == 63) ? 0 : next_head + 1;
                                next_count = next_count - 1;
                            end
                        end
                    end
                end
            end
        end
        
        head <= next_head;
        count <= next_count;
        
        if (triggered_exception) begin
            pending_exception <= True;
        end
        
        return tuple2(ret1, ret2);
    endmethod
    
    method Bool get_pending_exception();
        return pending_exception;
    endmethod
    
    method Action flush();
        head <= 0;
        tail <= 0;
        count <= 0;
        pending_exception <= False;
    endmethod

endmodule
endpackage
