package PhysicalRegisterFile;

import Vector::*;
import DiabloTypes::*;

interface PRF_IFC;
    method Action write1(PhysReg prd, bit[63:0] data);
    method Action write2(PhysReg prd, bit[63:0] data);
    method Action write3(PhysReg prd, bit[63:0] data);
    method Action write4(PhysReg prd, bit[63:0] data);
    method bit[63:0] read1(PhysReg prs1);
    method bit[63:0] read2(PhysReg prs2);
    method bit[63:0] read3(PhysReg prs3);
    method bit[63:0] read4(PhysReg prs4);
    method bit[63:0] read5(PhysReg prs5);
    method bit[63:0] read6(PhysReg prs6);
    method bit[63:0] read7(PhysReg prs7);
    method bit[63:0] read8(PhysReg prs8);
endinterface

// 96-entry Physical Register File for M0
(* synthesize *)
module mkPRF(PRF_IFC);
    Vector#(96, Reg#(bit[63:0])) regs <- replicateM(mkReg(0));
    
    Vector#(4, Wire#(Maybe#(Tuple2#(PhysReg, bit[63:0])))) wr_ports <- replicateM(mkDWire(tagged Invalid));
    
    rule do_writes;
        for (Integer j = 1; j < 96; j = j + 1) begin
            Bool w_match = False;
            bit[63:0] w_data = 0;
            for (Integer w = 0; w < 4; w = w + 1) begin
                if (wr_ports[w] matches tagged Valid .w_val) begin
                    if (tpl_1(w_val) == fromInteger(j)) begin
                        w_match = True;
                        w_data = tpl_2(w_val);
                    end
                end
            end
            if (w_match) begin
                regs[j] <= w_data;
            end
        end
    endrule
    
    method Action write1(PhysReg prd, bit[63:0] data); wr_ports[0] <= tagged Valid tuple2(prd, data); endmethod
    method Action write2(PhysReg prd, bit[63:0] data); wr_ports[1] <= tagged Valid tuple2(prd, data); endmethod
    method Action write3(PhysReg prd, bit[63:0] data); wr_ports[2] <= tagged Valid tuple2(prd, data); endmethod
    method Action write4(PhysReg prd, bit[63:0] data); wr_ports[3] <= tagged Valid tuple2(prd, data); endmethod
    
    method bit[63:0] read1(PhysReg prs1);
        if (prs1 == 0 || prs1 >= 96) return 0;
        else begin
            // Check for bypass
            bit[63:0] res = regs[prs1];
            for (Integer w = 0; w < 4; w = w + 1) begin
                if (wr_ports[w] matches tagged Valid .w_val) begin
                    if (tpl_1(w_val) == prs1) res = tpl_2(w_val);
                end
            end
            return res;
        end
    endmethod
    
    method bit[63:0] read2(PhysReg prs2);
        if (prs2 == 0 || prs2 >= 96) return 0;
        else begin
            // Check for bypass
            bit[63:0] res = regs[prs2];
            for (Integer w = 0; w < 4; w = w + 1) begin
                if (wr_ports[w] matches tagged Valid .w_val) begin
                    if (tpl_1(w_val) == prs2) res = tpl_2(w_val);
                end
            end
            return res;
        end
    endmethod

    method bit[63:0] read3(PhysReg prs);
        if (prs == 0 || prs >= 96) return 0;
        else begin
            bit[63:0] res = regs[prs];
            for (Integer w = 0; w < 4; w = w + 1) begin
                if (wr_ports[w] matches tagged Valid .w_val) begin
                    if (tpl_1(w_val) == prs) res = tpl_2(w_val);
                end
            end
            return res;
        end
    endmethod

    method bit[63:0] read4(PhysReg prs);
        if (prs == 0 || prs >= 96) return 0;
        else begin
            bit[63:0] res = regs[prs];
            for (Integer w = 0; w < 4; w = w + 1) begin
                if (wr_ports[w] matches tagged Valid .w_val) begin
                    if (tpl_1(w_val) == prs) res = tpl_2(w_val);
                end
            end
            return res;
        end
    endmethod

    method bit[63:0] read5(PhysReg prs);
        if (prs == 0 || prs >= 96) return 0;
        else begin
            bit[63:0] res = regs[prs];
            for (Integer w = 0; w < 4; w = w + 1) begin
                if (wr_ports[w] matches tagged Valid .w_val) begin
                    if (tpl_1(w_val) == prs) res = tpl_2(w_val);
                end
            end
            return res;
        end
    endmethod

    method bit[63:0] read6(PhysReg prs);
        if (prs == 0 || prs >= 96) return 0;
        else begin
            bit[63:0] res = regs[prs];
            for (Integer w = 0; w < 4; w = w + 1) begin
                if (wr_ports[w] matches tagged Valid .w_val) begin
                    if (tpl_1(w_val) == prs) res = tpl_2(w_val);
                end
            end
            return res;
        end
    endmethod

    method bit[63:0] read7(PhysReg prs);
        if (prs == 0 || prs >= 96) return 0;
        else begin
            bit[63:0] res = regs[prs];
            for (Integer w = 0; w < 4; w = w + 1) begin
                if (wr_ports[w] matches tagged Valid .w_val) begin
                    if (tpl_1(w_val) == prs) res = tpl_2(w_val);
                end
            end
            return res;
        end
    endmethod

    method bit[63:0] read8(PhysReg prs);
        if (prs == 0 || prs >= 96) return 0;
        else begin
            bit[63:0] res = regs[prs];
            for (Integer w = 0; w < 4; w = w + 1) begin
                if (wr_ports[w] matches tagged Valid .w_val) begin
                    if (tpl_1(w_val) == prs) res = tpl_2(w_val);
                end
            end
            return res;
        end
    endmethod

endmodule
endpackage
