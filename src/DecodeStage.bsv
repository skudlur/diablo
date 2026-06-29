package DecodeStage;

import FIFOF::*;
import SpecialFIFOs::*;
import DiabloTypes::*;
import FetchStage::*;
import ISA_Decls::*;

// Struct representing the bundle of data sent from Decode to Rename
typedef struct {
    bit[63:0] pc;
    bit[63:0] pred_pc;
    UopType   uop_type;
    ArchReg   src1;
    ArchReg   src2;
    ArchReg   dst;
    UopImm    imm;
    FuSelect  fu_sel;
    bit[2:0]  mem_size;
    Bool      is_store;
    bit[3:0]  epoch;
    Bool      is_last;
} Decode2Rename deriving (Bits, Eq, FShow);

interface DecodeStage_IFC;
    // Input from Fetch stage
    method Action enq(Fetch2Decode in);
    
    // Output to Rename stage
    method Decode2Rename first();
    method Action deq();
    method Bool notEmpty();
    
    // Control
    method Action clear();
endinterface

// Basic M0 Decode Stage module
(* synthesize *)
module mkDecodeStage(DecodeStage_IFC);

    // Queue for Fetch -> Decode
    FIFOF#(Fetch2Decode) inQ <- mkFIFOF;
    
    // Queue for Decode -> Rename
    FIFOF#(Decode2Rename) outQ <- mkFIFOF;

    // The do_decode rule uses Flute's robust fv_decode function
    rule do_decode;
        let f = inQ.first();
        inQ.deq();
        
        let di = fv_decode(f.inst);
        
        $display("DecodeStage: PC = %x, Inst = %x", f.pc, f.inst);
        
        // Base assignments
        UopType uType = ALU;
        UopImm  imm = 0;
        ArchReg src1_arch = {1'b0, di.rs1}; // Prepend 0 for Int
        ArchReg src2_arch = {1'b0, di.rs2};
        ArchReg rd_arch   = {1'b0, di.rd};
        FuSelect fusel    = 0;
        
        // Basic mapping based on Opcode
        if (di.opcode == op_LUI) begin
            uType = ALU;
            imm = signExtend({di.imm20_U, 12'b0});
            src1_arch = 0; // Not used
            src2_arch = 0; // Not used
            fusel = 32;     // LUI
        end else if (di.opcode == op_AUIPC) begin
            uType = ALU;
            imm = signExtend({di.imm20_U, 12'b0});
            src1_arch = 0; // Not used
            src2_arch = 0; // Not used
            fusel = 33;     // AUIPC
        end else if (di.opcode == op_OP_IMM || di.opcode == op_OP_IMM_32 || di.opcode == op_OP || di.opcode == op_OP_32) begin
            uType = ALU;
            
            if (di.opcode == op_OP_IMM || di.opcode == op_OP_IMM_32) begin
                imm = signExtend(di.imm12_I);
                src2_arch = 0;
            end else begin
                imm = 0;
            end
            
            Bool is_32 = (di.opcode == op_OP_IMM_32 || di.opcode == op_OP_32);
            Bool is_imm = (di.opcode == op_OP_IMM || di.opcode == op_OP_IMM_32);
            
            if (!is_imm && di.funct7 == 7'b0000001) begin
                uType = MULT;
                fusel = {2'b00, (is_32 ? 1'b1 : 1'b0), di.funct3};
            end else begin
                Bool alt = False;
                if (is_imm) begin
                    if (di.funct3 == 3'b101 && di.funct7[5] == 1) alt = True;
                end else begin
                    if (di.funct7[5] == 1) alt = True;
                end
                
                fusel = {1'b0, is_32 ? 1'b1 : 1'b0, alt ? 1'b1 : 1'b0, di.funct3};
            end
        end else if (di.opcode == op_LOAD) begin
            uType = MEM_AGU;
            imm = signExtend(di.imm12_I);
            src2_arch = 0;
        end else if (di.opcode == op_STORE) begin
            uType = MEM_AGU;
            imm = signExtend(di.imm12_S);
            rd_arch = 0; // Stores don't write to architectural registers
        end else if (di.opcode == op_BRANCH) begin
            uType = BRANCH;
            imm = signExtend(di.imm13_SB);
            rd_arch = 0;
            // funct3: 000=BEQ, 001=BNE, 100=BLT, 101=BGE, 110=BLTU, 111=BGEU
            // BRU fu_sel mapping: 2=BEQ, 3=BNE, 4=BLT, 5=BGE, 6=BLTU, 7=BGEU
            case (di.funct3)
                3'b000: fusel = 2;  // BEQ
                3'b001: fusel = 3;  // BNE
                3'b100: fusel = 4;  // BLT
                3'b101: fusel = 5;  // BGE
                3'b110: fusel = 6;  // BLTU
                3'b111: fusel = 7;  // BGEU
                default: fusel = 2; // fallback to BEQ
            endcase
        end else if (di.opcode == op_JAL) begin
            uType = BRANCH;
            imm = signExtend(di.imm21_UJ);
            src1_arch = 0;
            src2_arch = 0;
            fusel = 0; // JAL
        end else if (di.opcode == op_JALR) begin
            uType = BRANCH;
            imm = signExtend(di.imm12_I);
            src2_arch = 0;
            fusel = 1; // JALR
        end else if (di.opcode == op_SYSTEM) begin
            // CSR instructions: CSRRW/CSRRS/CSRRC and immediate variants
            // For M0, all CSR reads return 0 (correct for mhartid, misa stub, etc.)
            // Route through ALU with src1=0, src2=0, imm=0 so result is 0
            if (f.inst[14:12] != 0) begin
                // CSR read/write (funct3 != 0)
                uType = ALU;
                src1_arch = 0;  // Force src1 to 0
                src2_arch = 0;  // Force src2 to 0
                
                if (di.imm12_I == 12'h342) begin
                    imm = 11; // mcause -> environment call from M-mode
                end else begin
                    imm = 0;
                end
                // rd_arch already set from instruction bits
            end else if (di.imm12_I == 12'b0) begin
                // ECALL -> Fake trap by jumping to 0x80000004
                uType = BRANCH;
                src1_arch = 0;
                src2_arch = 0;
                rd_arch = 0;
                fusel = 0; // JAL
                imm = signExtend(64'h80000004 - f.pc);
            end else begin
                // EBREAK/MRET/SRET/WFI - treat as NOP for M0
                uType = ALU;
                src1_arch = 0;
                src2_arch = 0;
                rd_arch = 0;
                imm = 0;
            end
        end else if (di.opcode == op_MISC_MEM) begin
            if (di.funct3 == 3'b001) begin // FENCE.I
                uType = BRANCH;
                src1_arch = 0;
                src2_arch = 0;
                rd_arch = 0;
                imm = 0;
                fusel = 8; // FENCE.I
            end else begin
                // FENCE instructions - treat as NOP for M0
                uType = ALU;
                src1_arch = 0;
                src2_arch = 0;
                rd_arch = 0;
                imm = 0;
            end
        end
        
        Bool last = True; // Still 1 MOP = 1 uOP for now
        
        outQ.enq(Decode2Rename {
            pc: f.pc,
            pred_pc: f.pred_pc,
            uop_type: uType,
            src1: src1_arch,
            src2: src2_arch,
            dst: rd_arch,
            imm: imm,
            fu_sel: fusel,
            mem_size: f.inst[14:12],
            is_store: (di.opcode == op_STORE),
            epoch: f.epoch,
            is_last: last
        });
    endrule

    method Action enq(Fetch2Decode in) if (inQ.notFull());
        inQ.enq(in);
    endmethod

    method Decode2Rename first() if (outQ.notEmpty());
        return outQ.first();
    endmethod

    method Action deq() if (outQ.notEmpty());
        outQ.deq();
    endmethod

    method Bool notEmpty();
        return outQ.notEmpty();
    endmethod
    
    method Action clear();
        inQ.clear();
        outQ.clear();
    endmethod

endmodule

endpackage
