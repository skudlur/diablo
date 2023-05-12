module diablo(
input logic clk,
input logic reset
);

logic we;
logic [31:0]adr,din,instruction;
logic rd,opcode,i_type_imm,s_type_imm,b_type_imm,u_type_imm,j_type_imm; 
logic waddr_in, wdata_in, wen_in;
logic  control;
logic [63:0]imm, rdata_out1, rdata_out2, alu_output, aluin2;
logic [4:0]rs1,rs2;
logic [1:0]aluop;
logic [2:0]funct3;
logic [6:0]funct7;
logic [3:0]aluoperation;

assign adr = 0;
assign din  = 0;
assign dout = 0;

instruction_memory inst(clk, we, adr, din, instruction);
decode decoder(instruction, rs1, rs2, rd, opcode, funct3, funct7, i_type_imm, s_type_imm, b_type_imm, u_type_imm, j_type_imm);
int_regfile regfile(clk, reset,rs1,rs2,waddr_in, wdata_in, wen_in, rdata_out1, rdata_out2);
alu_mux alumux(rdata_out2, imm, control, aluin2);
immediate_generator immgen(instruction,imm);
alu aLU1(rdata_out1, aluin2, aluop, alu_output);
alu_control aluctr(aluop, funct7, funct3, aluoperation);

endmodule
