package ExecutionUnit;

import Vector::*;
import FIFOF::*;
import SpecialFIFOs::*;
import DiabloTypes::*;
import Near_Mem_IFC::*;
import MMU_Cache_Common::*;
import IssueQueue::*;
import ReorderBuffer::*;
import PhysicalRegisterFile::*;

// Result from Execution Unit
typedef struct {
    MopId     mop_id;
    PhysReg   prd;
    bit[63:0] data;
    bit[63:0] data_pc;
    Bool      excepting;
} ExeResult deriving (Bits, Eq, FShow);

interface ALU_IFC;
    // Input operands
    method Action execute(Uop u, bit[63:0] src1_data, bit[63:0] src2_data);
    
    // Result output
    method ExeResult get_result();
    method Action deq_result();
    method Bool has_result();
endinterface

// Branch Unit Interface
interface BranchUnit_IFC;
    method Action execute(Uop u, bit[63:0] src1_data, bit[63:0] src2_data);
    method ExeResult get_result();
    method Action deq_result();
    method Bool has_result();
    
    // M1 branch redirect bundle
    method Bool has_redirect();
    method bit[63:0] get_redirect_target();
    method Action clear_redirect();
    
    // For BTB updates
    method Bool was_taken();
    method bit[63:0] get_pc();
    method Bool is_fence_i();
    method bit[3:0] get_epoch();
endinterface

// Address Generation Unit (AGU) Interface
interface AGU_IFC;
    method Action execute(Uop u, bit[63:0] src1_data, bit[63:0] src2_data);
    method ExeResult get_result();
    method Action deq_result();
    method Bool has_result();
endinterface

// Multiplier Interface
interface Mult_IFC;
    method Action execute(Uop u, bit[63:0] src1_data, bit[63:0] src2_data);
    method ExeResult get_result();
    method Action deq_result();
    method Bool has_result();
endinterface

(* synthesize *)
module mkALU(ALU_IFC);

    FIFOF#(ExeResult) out_fifo <- mkPipelineFIFOF;

    method Action execute(Uop u, bit[63:0] src1_data, bit[63:0] src2_data) if (out_fifo.notFull());
        bit[63:0] op2 = (u.imm != 0) ? u.imm : src2_data;
        bit[63:0] out_data = 0;
        
        Bool is_32 = (u.fu_sel[4] == 1);
        Bool alt   = (u.fu_sel[3] == 1);
        bit[2:0] funct3 = u.fu_sel[2:0];
        
        if (u.fu_sel == 32) begin
            out_data = u.imm; // LUI
            $display("ALU: pc=%x LUI res=%x", u.pc, out_data);
        end else if (u.fu_sel == 33) begin
            out_data = u.pc + u.imm; // AUIPC
            $display("ALU: pc=%x AUIPC res=%x", u.pc, out_data);
        end else begin
            bit[63:0] add_res = src1_data + (alt ? (~op2 + 1) : op2);
            if (funct3 == 3'b000) begin
                out_data = add_res; // ADD / SUB
            end else if (funct3 == 3'b001) begin // SLL
                bit[5:0] shamt = is_32 ? {1'b0, op2[4:0]} : op2[5:0];
                out_data = src1_data << shamt;
            end else if (funct3 == 3'b010) begin // SLT
                Int#(64) s1 = unpack(src1_data);
                Int#(64) s2 = unpack(op2);
                out_data = (s1 < s2) ? 1 : 0;
            end else if (funct3 == 3'b011) begin // SLTU
                out_data = (src1_data < op2) ? 1 : 0;
            end else if (funct3 == 3'b100) begin // XOR
                out_data = src1_data ^ op2;
            end else if (funct3 == 3'b101) begin // SRL / SRA
                bit[5:0] shamt = is_32 ? {1'b0, op2[4:0]} : op2[5:0];
                if (alt) begin
                    if (is_32) begin
                        Int#(32) s1_32 = unpack(src1_data[31:0]);
                        out_data = signExtend(pack(s1_32 >> shamt));
                    end else begin
                        Int#(64) s1_64 = unpack(src1_data);
                        out_data = pack(s1_64 >> shamt);
                    end
                end else begin
                    if (is_32) begin
                        bit[31:0] s1_32 = src1_data[31:0];
                        out_data = signExtend(s1_32 >> shamt);
                    end else begin
                        out_data = src1_data >> shamt;
                    end
                end
            end else if (funct3 == 3'b110) begin // OR
                out_data = src1_data | op2;
            end else if (funct3 == 3'b111) begin // AND
                out_data = src1_data & op2;
            end
            
            if (is_32) begin
                out_data = signExtend(out_data[31:0]);
            end
            
            $display("ALU: pc=%x src1=%x op2=%x alt=%d funct3=%d res=%x", u.pc, src1_data, op2, alt, funct3, out_data);
        end
        
        out_fifo.enq(ExeResult {
            mop_id:    u.mop_id,
            prd:       u.prd,
            data:      out_data,
            data_pc:   0,
            excepting: False
        });
    endmethod
    
    method ExeResult get_result();
        return out_fifo.first();
    endmethod
    
    method Action deq_result();
        out_fifo.deq();
    endmethod
    
    method Bool has_result();
        return out_fifo.notEmpty();
    endmethod

endmodule

(* synthesize *)
module mkBranchUnit(BranchUnit_IFC);
    FIFOF#(ExeResult) out_fifo <- mkPipelineFIFOF;
    
    Reg#(Bool)      redirect_valid <- mkReg(False);
    Reg#(bit[63:0]) redirect_target <- mkReg(0);
    
    Reg#(Bool)      out_taken <- mkReg(False);
    Reg#(bit[63:0]) out_pc <- mkReg(0);
    Reg#(Bool)      out_fence_i <- mkReg(False);
    Reg#(bit[3:0])  saved_epoch <- mkReg(0);

    method Action execute(Uop u, bit[63:0] src1_data, bit[63:0] src2_data) if (out_fifo.notFull());
        Bool taken = False;
        bit[63:0] target = 0;
        
        // Very basic Branch decoding
        // JAL / JALR (Unconditional)
        if (u.fu_sel == 0) begin // JAL
            taken = True;
            target = u.pc + u.imm;
        end else if (u.fu_sel == 1) begin // JALR
            taken = True;
            target = (src1_data + u.imm) & ~64'b1;
        end else begin
            // Conditional branches (BEQ, BNE, etc.)
            // Assuming fu_sel 2=BEQ, 3=BNE, 4=BLT, 5=BGE, 6=BLTU, 7=BGEU
            let eq = (src1_data == src2_data);
            let lt = (signedCmp(src1_data, src2_data) < 0);
            let ltu = (src1_data < src2_data);
            
            if (u.fu_sel == 2) taken = eq;
            else if (u.fu_sel == 3) taken = !eq;
            else if (u.fu_sel == 4) taken = lt;
            else if (u.fu_sel == 5) taken = !lt;
            else if (u.fu_sel == 6) taken = ltu;
            else if (u.fu_sel == 7) taken = !ltu;
            else if (u.fu_sel == 8) taken = True; // FENCE.I
            
            if (u.fu_sel == 8) begin
                target = u.pc + 4;
            end else begin
                target = u.pc + u.imm;
            end
        end
        
        bit[63:0] correct_next_pc = taken ? target : (u.pc + 4);
        if (correct_next_pc != u.pred_pc || u.fu_sel == 8) begin // FENCE.I always redirects to flush Fetch
            redirect_valid <= True;
            redirect_target <= correct_next_pc;
        end
        
        out_taken <= taken;
        out_pc <= u.pc;
        saved_epoch <= u.epoch;
        out_fence_i <= (u.fu_sel == 8);
        
        $display("BRU: pc=%x src1=%x src2=%x taken=%d target=%x", u.pc, src1_data, src2_data, taken, target);
        
        out_fifo.enq(ExeResult {
            mop_id:    u.mop_id,
            prd:       u.prd,
            data:      u.pc + 4, // JAL/JALR saves return address (PC+4)
            data_pc:   0,
            excepting: False
        });
    endmethod
    
    method ExeResult get_result();
        return out_fifo.first();
    endmethod
    
    method Action deq_result();
        out_fifo.deq();
    endmethod
    
    method Bool has_result();
        return out_fifo.notEmpty();
    endmethod
    
    method Bool has_redirect();
        return redirect_valid;
    endmethod
    
    method bit[63:0] get_redirect_target();
        return redirect_target;
    endmethod
    
    method Action clear_redirect();
        redirect_valid <= False;
    endmethod
    
    method Bool was_taken();
        return out_taken;
    endmethod
    
    method bit[63:0] get_pc();
        return out_pc;
    endmethod
    
    method bit[3:0] get_epoch();
        return saved_epoch;
    endmethod
    
    method Bool is_fence_i();
        return out_fence_i;
    endmethod
endmodule

// ----------------------------------------------------------------
// Address Generation Unit (AGU) & Memory Unit
// ----------------------------------------------------------------
module mkAGU#(DMem_IFC dmem) (AGU_IFC);
    FIFOF#(ExeResult) out_fifo <- mkPipelineFIFOF;
    
    Reg#(Bool) waiting_for_mem <- mkReg(False);
    Reg#(Uop)  cur_uop <- mkReg(?);
    Reg#(bit[63:0]) saved_addr <- mkReg(0);
    
    rule do_mem_rsp (waiting_for_mem && dmem.valid());
        waiting_for_mem <= False;
        
        bit[63:0] extracted_data = 0;
        if (!cur_uop.is_store) begin
            extracted_data = dmem.word64();
        end
        
        $display("AGU_RSP: pc=%x data=%x", cur_uop.pc, extracted_data);
        
        out_fifo.enq(ExeResult {
            mop_id:    cur_uop.mop_id,
            prd:       cur_uop.prd,
            data:      extracted_data,
            data_pc:   cur_uop.pc,
            excepting: dmem.exc()
        });
    endrule

    Reg#(Bit#(64)) cycle_count <- mkReg(0);
    rule count_cycles;
        cycle_count <= cycle_count + 1;
    endrule


    method Action execute(Uop u, bit[63:0] src1_data, bit[63:0] src2_data) if (out_fifo.notFull() && !waiting_for_mem);
        bit[63:0] addr = src1_data + u.imm;
        saved_addr <= addr;
        cur_uop <= u;
        
        CacheOp op = CACHE_LD;
        if (u.is_serialize && u.fu_sel == 34) begin
            op = CACHE_AMO;
        end else if (u.is_store) begin
            op = CACHE_ST;
        end
        
        if (op == CACHE_ST && addr == 64'hC0000000) begin
            $display("UART: %c", src2_data[7:0]);
            out_fifo.enq(ExeResult {
                mop_id:    u.mop_id,
                prd:       0,
                data:      0,
                data_pc:   u.pc,
                excepting: False
            });
        end else if (op == CACHE_LD && addr == 64'hC0000008) begin
            $display("CYCLE READ: %0d at addr %x", cycle_count, addr);
            out_fifo.enq(ExeResult {
                mop_id:    u.mop_id,
                prd:       u.prd,
                data:      cycle_count,
                data_pc:   u.pc,
                excepting: False
            });
        end else begin
            $display("AGU: pc=%x op=%x addr=%x src2=%x size=%d", u.pc, op, addr, src2_data, u.mem_size);
            dmem.req(op, u.mem_size, u.amo_func7, addr, src2_data, 3 /* M-Mode */, 0, 0, 0);
            waiting_for_mem <= True;
        end
    endmethod

    method Bool has_result();
        return out_fifo.notEmpty();
    endmethod

    method ExeResult get_result();
        return out_fifo.first();
    endmethod

    method Action deq_result();
        out_fifo.deq();
    endmethod
endmodule

(* synthesize *)
module mkMultUnit(Mult_IFC);
    FIFOF#(ExeResult) out_fifo <- mkPipelineFIFOF;

    method Action execute(Uop u, bit[63:0] src1_data, bit[63:0] src2_data) if (out_fifo.notFull());
        bit[63:0] result = 0;
        
        Bool is_32 = (u.fu_sel[3] == 1);
        bit[2:0] funct3 = u.fu_sel[2:0];
        
        Int#(64) rs1_signed = unpack(src1_data);
        Int#(64) rs2_signed = unpack(src2_data);
        
        Int#(128) rs1_128_s = signExtend(rs1_signed);
        Int#(128) rs2_128_s = signExtend(rs2_signed);
        
        UInt#(64) rs1_unsigned = unpack(src1_data);
        UInt#(64) rs2_unsigned = unpack(src2_data);
        
        UInt#(128) rs1_128_u = zeroExtend(rs1_unsigned);
        UInt#(128) rs2_128_u = zeroExtend(rs2_unsigned);
        
        if (funct3 == 3'b000) begin // MUL
            result = src1_data * src2_data;
        end else if (funct3 == 3'b001) begin // MULH
            Int#(128) p = rs1_128_s * rs2_128_s;
            result = pack(p)[127:64];
        end else if (funct3 == 3'b010) begin // MULHSU
            Int#(128) rs2_128_su = unpack(zeroExtend(src2_data));
            Int#(128) p = rs1_128_s * rs2_128_su;
            result = pack(p)[127:64];
        end else if (funct3 == 3'b011) begin // MULHU
            UInt#(128) p = rs1_128_u * rs2_128_u;
            result = pack(p)[127:64];
        end else if (funct3 == 3'b100) begin // DIV
            if (src2_data == 0) result = '1;
            else if (src1_data == 64'h8000000000000000 && src2_data == '1) result = src1_data;
            else result = pack(rs1_signed / rs2_signed);
        end else if (funct3 == 3'b101) begin // DIVU
            if (src2_data == 0) result = '1;
            else result = pack(rs1_unsigned / rs2_unsigned);
        end else if (funct3 == 3'b110) begin // REM
            if (src2_data == 0) result = src1_data;
            else if (src1_data == 64'h8000000000000000 && src2_data == '1) result = 0;
            else result = pack(rs1_signed % rs2_signed);
        end else if (funct3 == 3'b111) begin // REMU
            if (src2_data == 0) result = src1_data;
            else result = pack(rs1_unsigned % rs2_unsigned);
        end
        
        // 32-bit operations
        if (is_32) begin
            if (funct3 == 3'b000) begin // MULW
                result = signExtend((src1_data[31:0] * src2_data[31:0])[31:0]);
            end else if (funct3 == 3'b100) begin // DIVW
                Int#(32) rs1_32_s = unpack(src1_data[31:0]);
                Int#(32) rs2_32_s = unpack(src2_data[31:0]);
                if (src2_data[31:0] == 0) result = '1;
                else if (src1_data[31:0] == 32'h80000000 && src2_data[31:0] == '1) result = signExtend(src1_data[31:0]);
                else result = signExtend(pack(rs1_32_s / rs2_32_s));
            end else if (funct3 == 3'b101) begin // DIVUW
                UInt#(32) rs1_32_u = unpack(src1_data[31:0]);
                UInt#(32) rs2_32_u = unpack(src2_data[31:0]);
                if (src2_data[31:0] == 0) result = '1;
                else result = signExtend(pack(rs1_32_u / rs2_32_u));
            end else if (funct3 == 3'b110) begin // REMW
                Int#(32) rs1_32_s = unpack(src1_data[31:0]);
                Int#(32) rs2_32_s = unpack(src2_data[31:0]);
                if (src2_data[31:0] == 0) result = signExtend(src1_data[31:0]);
                else if (src1_data[31:0] == 32'h80000000 && src2_data[31:0] == '1) result = 0;
                else result = signExtend(pack(rs1_32_s % rs2_32_s));
            end else if (funct3 == 3'b111) begin // REMUW
                UInt#(32) rs1_32_u = unpack(src1_data[31:0]);
                UInt#(32) rs2_32_u = unpack(src2_data[31:0]);
                if (src2_data[31:0] == 0) result = signExtend(src1_data[31:0]);
                else result = signExtend(pack(rs1_32_u % rs2_32_u));
            end
        end

        out_fifo.enq(ExeResult {
            mop_id:    u.mop_id,
            prd:       u.prd,
            data:      result,
            data_pc:   0,
            excepting: False
        });
    endmethod
    
    method ExeResult get_result();
        return out_fifo.first();
    endmethod
    
    method Action deq_result();
        out_fifo.deq();
    endmethod
    
    method Bool has_result();
        return out_fifo.notEmpty();
    endmethod
endmodule

function Int#(64) signedCmp(bit[63:0] a, bit[63:0] b);
    Int#(64) sa = unpack(a);
    Int#(64) sb = unpack(b);
    return sa - sb;
endfunction

// Helper function to check the RWire bypass network before reading the PRF
function bit[63:0] bypassCheck(Maybe#(Tuple2#(PhysReg, bit[63:0])) bypass_wire, PhysReg prs, bit[63:0] prf_data);
    bit[63:0] res = prf_data;
    if (isValid(bypass_wire)) begin
        let bp = fromMaybe(?, bypass_wire);
        if (tpl_1(bp) == prs && prs != 0) begin
            res = tpl_2(bp); // Use bypassed data
        end
    end
    return res;
endfunction

endpackage
