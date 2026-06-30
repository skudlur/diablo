package DiabloCore;

import DiabloTypes::*;
import FetchStage::*;
import DecodeStage::*;
import RenameStage::*;
import IssueQueue::*;
import ReorderBuffer::*;
import PhysicalRegisterFile::*;
import ExecutionUnit::*;

import ClientServer::*;
import GetPut::*;
import ISA_Decls::*;

// Flute Memory Subsystem
import Near_Mem_IFC::*;
`ifdef Near_Mem_Caches
import Near_Mem_Caches::*;
`endif
`ifdef Near_Mem_TCM
import Near_Mem_TCM::*;
`endif
import AXI4_Types::*;
import AXI_Widths::*;
import Fabric_Defs::*;

interface DiabloCore_IFC;
    method Action start(bit[63:0] pc);
    
    // Memory interfaces to fabric
    interface AXI4_Master_IFC #(Wd_Id, Wd_Addr, Wd_Data, Wd_User) imem_master;
    interface Near_Mem_Fabric_IFC mem_master;
    
    // DMA server
    interface AXI4_Slave_IFC #(Wd_Id_Dma, Wd_Addr_Dma, Wd_Data_Dma, Wd_User_Dma) dma_server;
    
    // Reset and fences
    interface Server #(Token, Token) server_reset;
    interface Server #(Fence_Ordering, Token) server_fence;
`ifdef ISA_PRIV_S
    interface Server #(Token, Token) sfence_vma_server;
`endif
    
    // Status
    method Bit #(8) mv_status;
    method Action ma_ddr4_ready;
    
`ifdef WATCH_TOHOST
    method Action set_watch_tohost(Bool watch, bit[63:0] addr);
    method bit[63:0] mv_tohost_value;
`endif
endinterface

(* synthesize *)
module mkDiabloCore(DiabloCore_IFC);

    Near_Mem_IFC           near_mem <- mkNear_Mem;

    // Stats
    Reg#(UInt#(64)) cur_cycle <- mkReg(0);

    FetchStage_IFC         fetch  <- mkFetchStage(near_mem.imem);
    DecodeStage_IFC        decode <- mkDecodeStage;
    RenameStage_IFC        rename <- mkRenameStage;
    IssueQueue_IFC         iq     <- mkIssueQueue;
    ReorderBuffer_IFC      rob    <- mkReorderBuffer;
    PRF_IFC                prf    <- mkPRF;
    ALU_IFC                alu    <- mkALU;
    BranchUnit_IFC         bru    <- mkBranchUnit;
    AGU_IFC                agu    <- mkAGU(near_mem.dmem);
    Mult_IFC               mult   <- mkMultUnit;

    Reg#(Bool)             pending_redirect <- mkReg(False);
    Reg#(bit[63:0])        redirect_target  <- mkReg(0);
    Reg#(bit[3:0])         epoch            <- mkReg(0);



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
        let id <- rob.allocate(u.is_last, u.prd, u.old_prd, 0, 0);
        
        // Attach the allocated ROB ID to the Uop
        u.mop_id = id;
        
        // Dispatch to Issue Queue
        iq.dispatch(u);
        $display("Cycle %0d: Rename/Dispatch PC = %x, mop_id = %x, prd = %d", cur_cycle, u.pc, u.mop_id, u.prd);
    endrule

    // Stage 4: Issue -> Execute
    rule issue_alu (iq.has_ready_ALU());
        let uop <- iq.issue_ALU();
        let src1 = prf.read1(uop.prs1);
        let src2 = prf.read2(uop.prs2);
        alu.execute(uop, src1, src2);
        $display("Cycle %0d: Issue ALU PC = %x", cur_cycle, uop.pc);
    endrule

    rule issue_agu (iq.has_ready_MEM_AGU());
        let uop <- iq.issue_MEM_AGU();
        let src1 = prf.read1(uop.prs1);
        let src2 = prf.read2(uop.prs2);
        agu.execute(uop, src1, src2);
        $display("Cycle %0d: Issue AGU PC = %x", cur_cycle, uop.pc);
    endrule

    rule issue_mult (iq.has_ready_MULT());
        let uop <- iq.issue_MULT();
        let src1 = prf.read1(uop.prs1);
        let src2 = prf.read2(uop.prs2);
        mult.execute(uop, src1, src2);
        $display("Cycle %0d: Issue MULT PC = %x", cur_cycle, uop.pc);
    endrule

    rule issue_bru (iq.has_ready_BRANCH());
        let uop <- iq.issue_BRANCH();
        let src1 = prf.read1(uop.prs1);
        let src2 = prf.read2(uop.prs2);
        bru.execute(uop, src1, src2);
        $display("Cycle %0d: Issue BRU PC = %x", cur_cycle, uop.pc);
    endrule

    Reg#(Bool) pending_fence_i <- mkReg(False);
    Reg#(Bool) waiting_fence_i <- mkReg(False);
    
    rule handle_fence_i_req (pending_fence_i && !waiting_fence_i);
        near_mem.server_fence_i.request.put(?);
        waiting_fence_i <= True;
        //$display("Cycle %0d: DiabloCore: sent server_fence_i.request", cur_cycle);
    endrule

    rule handle_fence_i_rsp (waiting_fence_i);
        let rsp <- near_mem.server_fence_i.response.get();
        pending_fence_i <= False;
        waiting_fence_i <= False;
        fetch.cache_flushed();
        //$display("Cycle %0d: DiabloCore: received server_fence_i.response", cur_cycle);
    endrule

    // Stage 5: Execute -> Writeback & Wakeup
    rule execute_writeback (!pending_redirect && !pending_fence_i);
        if (bru.has_result()) begin
            let res = bru.get_result();
            bru.deq_result();
            if (res.prd != 0) begin
                prf.write1(res.prd, res.data);
                iq.wakeup1(res.prd);
                rename.wakeup1(res.prd);
            end
            rob.complete1(res.mop_id, res.excepting);
            if (bru.has_redirect()) begin
                pending_redirect <= True;
                redirect_target <= bru.get_redirect_target();
                if (bru.is_fence_i()) begin
                    pending_fence_i <= True;
                end else begin
                    fetch.update_btb(bru.get_pc(), bru.get_redirect_target(), bru.was_taken());
                end
                bru.clear_redirect();
            end else begin
                rename.resolve_correct_branch();
            end
        end
        if (agu.has_result()) begin
            let res = agu.get_result();
            agu.deq_result();
            if (res.prd != 0) begin
                prf.write2(res.prd, res.data);
                iq.wakeup2(res.prd);
                rename.wakeup2(res.prd);
            end
            rob.complete2(res.mop_id, res.excepting);
        end
        if (mult.has_result()) begin
            let res = mult.get_result();
            mult.deq_result();
            if (res.prd != 0) begin
                prf.write3(res.prd, res.data);
                iq.wakeup3(res.prd);
                rename.wakeup3(res.prd);
            end
            rob.complete3(res.mop_id, res.excepting);
        end
        if (alu.has_result()) begin
            let res = alu.get_result();
            alu.deq_result();
            if (res.prd != 0) begin
                prf.write4(res.prd, res.data);
                iq.wakeup4(res.prd);
                rename.wakeup4(res.prd);
            end
            rob.complete4(res.mop_id, res.excepting);
        end
    endrule

    // Stage 6: Commit -> Retire
    rule commit_retire (!rob.get_pending_exception() && rob.is_head_completed());
        let r <- rob.commit();
        let ret1 = tpl_1(r);
        let ret2 = tpl_2(r);
        
        if (isValid(ret1)) begin
            let slot = fromMaybe(?, ret1);
            $display("Cycle %0d: Commit Retire, mop_id = %x", cur_cycle, slot);
            rename.commitRegister(slot.old_prd);
        end
        // Note: ret2 register freeing deferred - single commit port for now
        // if (isValid(ret2)) begin
        //     let slot = fromMaybe(?, ret2);
        //     // Free via second port when available
        // end
    endrule
    
    // Exception / Flush Rule
    rule handle_exception (rob.get_pending_exception() || pending_redirect);
        let next_epoch = epoch + 1;
        epoch <= next_epoch;
        
        if (rob.get_pending_exception()) begin
            // For M0, redirect fetch to exception handler PC 0x80000004
            fetch.redirect(64'h80000004, next_epoch); 
        end else begin
            // Branch mispredict redirect
            fetch.redirect(redirect_target, next_epoch);
        end
        
        decode.clear();
        rename.flush(next_epoch);
        
        pending_redirect <= False;
    endrule
    
    // Debug rule removed - re-enable when needed

    rule inc_cycle;
        cur_cycle <= cur_cycle + 1;
    endrule

    // --- Core Interface ---

    method Action start(bit[63:0] pc);
        fetch.start(pc);
    endmethod

    interface imem_master = near_mem.imem_master;
    interface mem_master  = near_mem.mem_master;
    interface dma_server  = near_mem.dma_server;
    interface server_reset = near_mem.server_reset;
    interface server_fence = near_mem.server_fence;
`ifdef ISA_PRIV_S
    interface sfence_vma_server = near_mem.sfence_vma_server;
`endif
    
    method Bit #(8) mv_status;
        return near_mem.mv_status;
    endmethod
    
    method Action ma_ddr4_ready;
        near_mem.ma_ddr4_ready();
    endmethod

`ifdef WATCH_TOHOST
    method Action set_watch_tohost(Bool watch, bit[63:0] addr);
        near_mem.set_watch_tohost(watch, addr);
    endmethod
    
    method bit[63:0] mv_tohost_value;
        return near_mem.mv_tohost_value();
    endmethod
`endif
endmodule

endpackage
