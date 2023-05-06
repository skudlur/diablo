module alu_pc(pccurrent,updatedpc);
input logic [63:0] pccurrent;
output logic [63:0] updatedpc;
assign updatedpc = pccurrent + 4;
endmodule
