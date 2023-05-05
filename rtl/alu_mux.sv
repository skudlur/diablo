module alu_mux( input logic [63:0]reg2,imm,
input logic control,
output logic [63:0]aluin2
);

    assign aluin2 = control ? reg2 : imm; 



endmodule




