package ExecutionUnit;

import DiabloTypes::*;
import IssueQueue::*;
import ReorderBuffer::*;
import PhysicalRegisterFile::*;

// Result from Execution Unit
typedef struct {
    MopId     mop_id;
    PhysReg   prd;
    bit[63:0] data;
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

(* synthesize *)
module mkALU(ALU_IFC);

    // 1-cycle latency pipeline register
    Reg#(Bool)      valid <- mkReg(False);
    Reg#(ExeResult) res <- mkReg(unpack(0));

    method Action execute(Uop u, bit[63:0] src1_data, bit[63:0] src2_data) if (!valid);
        bit[63:0] out_data = 0;
        
        // Very basic ALU decoding for M0 (ADD / SUB / etc)
        // Assume fu_sel == 0 is ADD, fu_sel == 1 is SUB
        if (u.fu_sel == 0) begin
            out_data = src1_data + src2_data;
        end else if (u.fu_sel == 1) begin
            out_data = src1_data - src2_data;
        end else begin
            out_data = src1_data; // Default pass-through
        end
        
        // Handle immediate values (simplified: if imm is non-zero, assume it's an immediate operation like ADDI)
        if (u.imm != 0) begin
             out_data = src1_data + u.imm;
        end
        
        res <= ExeResult {
            mop_id:    u.mop_id,
            prd:       u.prd,
            data:      out_data,
            excepting: False
        };
        valid <= True;
    endmethod
    
    method ExeResult get_result() if (valid);
        return res;
    endmethod
    
    method Action deq_result() if (valid);
        valid <= False;
    endmethod
    
    method Bool has_result();
        return valid;
    endmethod

endmodule

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
