package Tb;

import DiabloTypes::*;
import DiabloCore::*;

(* synthesize *)
module mkTb (Empty);

    Reg#(int) cycle <- mkReg(0);
    DiabloCore_IFC core <- mkDiabloCore;

    rule start_core (cycle == 0);
        core.start(64'h1000); // Dummy boot PC
    endrule

    rule count_cycles;
        cycle <= cycle + 1;
        $display("Cycle %0d", cycle);
        if (cycle > 10) begin
            $display("SUCCESS: DiabloCore M0 pipeline compiled and ran for 10 cycles.");
            $finish(0);
        end
    endrule

endmodule

endpackage
