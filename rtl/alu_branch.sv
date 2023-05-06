module alu_branch(pccurrent,pcoffset,updatedpc);
input logic [63:0]pccurrent;
input logic [63:0]pcoffset;
output logic [63:0]updatedpc;
assign updatedpc = pccurrent + pcoffset;
endmodule

