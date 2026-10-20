package FetchStage;

import FIFOF::*;
import SpecialFIFOs::*;
import Vector::*;
import ConfigReg::*;
import DiabloTypes::*;

// Struct representing the bundle of data sent from Fetch to Decode
typedef struct {
    bit[63:0] pc;
    bit[63:0] pred_pc;
    bit[31:0] inst; // 32-bit instruction
    bit[3:0]  epoch; // Branch prediction epoch
} Fetch2Decode deriving (Bits, Eq, FShow);

import Near_Mem_IFC::*;
import ISA_Decls::*;

interface FetchStage_IFC;
    method Action start(bit[63:0] start_pc);
    method Action redirect(bit[63:0] new_pc, bit[3:0] new_epoch);
    method Action pause();
    method Action cache_flushed();
    
    // Output to Decode
    method Fetch2Decode first();
    method Action deq();
    method Bool notEmpty();
    
    // Branch Predictor updates from execution
    method Action update_btb(bit[63:0] update_pc, bit[63:0] target, Bool taken);
endinterface

module mkFetchStage#(IMem_IFC imem) (FetchStage_IFC);
    
    FIFOF#(Fetch2Decode) fBuffer <- mkFIFOF;
    
    Reg#(bit[63:0]) pc_reg <- mkReg(0);
    Reg#(bit[3:0])  epoch_reg <- mkReg(0);
    Reg#(Bool)    active <- mkReg(False);
    Reg#(Bool)    waiting_for_imem[2] <- mkCReg(2, False);
    Reg#(bit[63:0]) spec_pred_pc <- mkReg(0);
    Reg#(bit[3:0])  fetch_epoch <- mkReg(0);
    
    Vector#(256, Reg#(bit[63:0])) btb_target <- replicateM(mkReg(0));
    Vector#(256, Reg#(bit[63:0])) btb_tag <- replicateM(mkReg(0));
    Vector#(256, Reg#(Bool))      btb_valid <- replicateM(mkReg(False));
    Vector#(256, Reg#(bit[1:0]))  bht <- replicateM(mkReg(2'b10)); // 2-bit counter

    Reg#(Bit#(64)) cycles <- mkReg(0);
    rule count; cycles <= cycles + 1; endrule

    // Rule 2: Receive response from I_MMU_Cache
    // By putting this rule first, BSV may schedule it before do_fetch_req
    rule do_fetch_rsp (waiting_for_imem[0] && imem.valid());
        if (!imem.exc()) begin
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
        end
        waiting_for_imem[0] <= False;
    endrule

    // Rule 1: Send request to I_MMU_Cache
    // Notice we do NOT check fBuffer.notFull(). If fBuffer is full, do_fetch_rsp will not fire,
    // so waiting_for_imem[0] will not be cleared, so waiting_for_imem[1] will be True,
    // preventing do_fetch_req from firing.
    rule do_fetch_req (active && !waiting_for_imem[1]);
        // Predict next PC
        bit[7:0] idx = truncate(pc_reg >> 2);
        bit[63:0] next_pc = pc_reg + 4;
        if (btb_valid[idx] && btb_tag[idx] == pc_reg) begin
            if (bht[idx] >= 2) begin
                next_pc = btb_target[idx];
            end
        end
        
        imem.req(3'b010, pc_reg, 3 /* M-Mode */, 0, 0, 0);
        
        spec_pred_pc <= next_pc;
        pc_reg <= next_pc;
        waiting_for_imem[1] <= True;
        fetch_epoch <= epoch_reg;
    endrule

    method Action start(bit[63:0] start_pc) if (!active);
        pc_reg <= start_pc;
        active <= True;
        waiting_for_imem[0] <= False;
        fBuffer.clear();
    endmethod

    method Action redirect(bit[63:0] new_pc, bit[3:0] new_epoch);
        pc_reg <= new_pc;
        epoch_reg <= new_epoch;
        fBuffer.clear(); // Flush the fetch buffer on redirect
    endmethod
    method Action pause();
        active <= False;
    endmethod
    
    method Action cache_flushed();
        active <= True;
    endmethod
    
    method Action update_btb(bit[63:0] update_pc, bit[63:0] target, Bool taken);
        bit[7:0] idx = truncate(update_pc >> 2);
        btb_valid[idx] <= True;
        btb_tag[idx] <= update_pc;
        btb_target[idx] <= target;
        
        bit[1:0] old_bht = bht[idx];
        if (taken) begin
            if (old_bht != 2'b11) bht[idx] <= old_bht + 1;
        end else begin
            if (old_bht != 2'b00) bht[idx] <= old_bht - 1;
        end
    endmethod

    // Read interface for Decode
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
