package PhysicalRegisterFile;

import Vector::*;
import DiabloTypes::*;

interface PRF_IFC;
    method Action write(PhysReg prd, bit[63:0] data);
    method bit[63:0] read1(PhysReg prs1);
    method bit[63:0] read2(PhysReg prs2);
endinterface

// 96-entry Physical Register File for M0
(* synthesize *)
module mkPRF(PRF_IFC);
    Vector#(96, Reg#(bit[63:0])) regs <- replicateM(mkReg(0));
    
    method Action write(PhysReg prd, bit[63:0] data);
        if (prd != 0 && prd < 96) begin
            regs[prd] <= data;
        end
    endmethod
    
    method bit[63:0] read1(PhysReg prs1);
        if (prs1 == 0 || prs1 >= 96) return 0;
        else return regs[prs1];
    endmethod
    
    method bit[63:0] read2(PhysReg prs2);
        if (prs2 == 0 || prs2 >= 96) return 0;
        else return regs[prs2];
    endmethod

endmodule
endpackage
