package Tb;

import DiabloTypes::*;

(* synthesize *)
module mkTb (Empty);

    Reg#(int) cycle <- mkReg(0);

    rule count_cycles;
        cycle <= cycle + 1;
        if (cycle > 5) begin
            $display("SUCCESS: Testbench ran to completion.");
            $finish(0);
        end
    endrule

    rule test_types (cycle == 1);
        IssueSlot slot = unpack(0);
        slot.uop_type = UOP_ALU;
        slot.prd = 7'd10;
        slot.prs1_rdy = True;
        
        $display("Created IssueSlot: uop_type=%0d, prd=%0d, prs1_rdy=%0d", 
                 slot.uop_type, slot.prd, slot.prs1_rdy);
                 
        RobSlot rob = unpack(0);
        rob.is_last = True;
        rob.prd = 7'd10;
        rob.ard = 5'd1;
        
        $display("Created RobSlot: is_last=%0d, prd=%0d, ard=%0d", 
                 rob.is_last, rob.prd, rob.ard);
    endrule

endmodule

endpackage
