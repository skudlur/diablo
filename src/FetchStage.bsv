package FetchStage;

import FIFOF::*;
import SpecialFIFOs::*;
import Vector::*;
import DiabloTypes::*;

// Struct representing the bundle of data sent from Fetch to Decode
typedef struct {
    bit[63:0] pc;
    bit[63:0] pred_pc;
    bit[31:0] inst; // 32-bit instruction
    bit[3:0]  epoch; // Branch prediction epoch
} Fetch2Decode deriving (Bits, Eq, FShow);

interface FetchStage_IFC;
    // Core pipeline control
    method Action start(bit[63:0] start_pc);
    method Action redirect(bit[63:0] new_pc, bit[3:0] new_epoch);
    method Action cache_flushed();
    method Action update_btb(bit[63:0] pc, bit[63:0] target, Bool taken);
    
    // Output to Decode stage
    method Fetch2Decode first();
    method Action deq();
    method Bool notEmpty();
    
    // (Future: IMem / ITLB interfaces will go here)
endinterface

import Near_Mem_IFC::*;
import ISA_Decls::*;

// Simple M0 Fetch Stage module
module mkFetchStage#(IMem_IFC imem) (FetchStage_IFC);

    // Fetch Buffer: 8-entry FIFOF
    FIFOF#(Fetch2Decode) fBuffer <- mkSizedFIFOF(8);
    
    // Architectural state
    Reg#(bit[63:0]) pc_reg <- mkReg(0);
    Reg#(bit[3:0])  epoch_reg <- mkReg(0);
    Reg#(Bool)    active <- mkReg(False);
    Reg#(Bool)    waiting_for_imem <- mkReg(False);
    Reg#(bit[63:0]) spec_pred_pc <- mkReg(0);
    Reg#(bit[3:0])  fetch_epoch <- mkReg(0);
    
    // Simple 16-entry BTB
    Vector#(16, Reg#(bit[63:0])) btb_tag <- replicateM(mkReg(0));
    Vector#(16, Reg#(bit[63:0])) btb_target <- replicateM(mkReg(0));
    Vector#(16, Reg#(Bool))      btb_valid <- replicateM(mkReg(False));

    Reg#(Bit#(64)) cycles <- mkReg(0);
    rule count; cycles <= cycles + 1; endrule

    // Rule 1: Send request to I_MMU_Cache
    rule do_fetch_req (active && fBuffer.notFull() && !waiting_for_imem);
        // Predict next PC
        bit[3:0] idx = truncate(pc_reg >> 2);
        bit[63:0] next_pc = pc_reg + 4;
        if (btb_valid[idx] && btb_tag[idx] == pc_reg) begin
            next_pc = btb_target[idx];
        end
        
        //$display("FetchStage: Requesting PC = %x", pc_reg);
        imem.req(3'b010, pc_reg, 3 /* M-Mode */, 0, 0, 0);
        
        spec_pred_pc <= next_pc;
        pc_reg <= next_pc;
        waiting_for_imem <= True;
        fetch_epoch <= epoch_reg;
    endrule

    // Rule 2: Receive response from I_MMU_Cache
    rule do_fetch_rsp (waiting_for_imem && imem.valid());
        if (!imem.exc()) begin
            // //$display("FetchStage: Response PC = %x, Inst = %x", imem.pc(), imem.instr());
            if (fetch_epoch == epoch_reg) begin
                fBuffer.enq(Fetch2Decode {
                    pc: imem.pc(),
                    pred_pc: spec_pred_pc,
                    inst: imem.instr(),
                    epoch: fetch_epoch
                });
            end
        end else begin
            //$display("FetchStage: Exception at PC = %x", imem.pc());
            // Instruction page fault / access fault handling
            // For now, we drop it or enq a NOP.
        end
        waiting_for_imem <= False;
    endrule

    method Action start(bit[63:0] start_pc) if (!active);
        pc_reg <= start_pc;
        active <= True;
        waiting_for_imem <= False;
    endmethod

    method Action redirect(bit[63:0] new_pc, bit[3:0] new_epoch);
        pc_reg <= new_pc;
        epoch_reg <= new_epoch;
        fBuffer.clear(); // Flush the fetch buffer on redirect
    endmethod
    
    method Action cache_flushed();
        waiting_for_imem <= False;
    endmethod
    
    method Action update_btb(bit[63:0] update_pc, bit[63:0] target, Bool taken);
        bit[3:0] idx = truncate(update_pc >> 2);
        if (taken) begin
            btb_tag[idx] <= update_pc;
            btb_target[idx] <= target;
            btb_valid[idx] <= True;
        end else begin
            if (btb_tag[idx] == update_pc) begin
                btb_valid[idx] <= False;
            end
        end
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
