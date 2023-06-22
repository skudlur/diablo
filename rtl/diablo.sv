module diablo(
input logic clk,
input logic reset
);

logic we;
logic [31:0]adr,din,instruction;
logic rd,i_type_imm,s_type_imm,b_type_imm,u_type_imm,j_type_imm; 
logic waddr_in, wdata_in;
logic alusrc;
logic [63:0]imm, rdata_out1, rdata_out2, alu_output, aluin2;
logic [4:0]rs1,rs2;
logic [1:0]aluop;
logic [2:0]funct3;
logic [6:0]funct7,opcode;
logic [3:0]aluoperation;
logic MemtoReg,RegtoMem, RegWrite, MemRead,MemWrite,branch ;
logic Con_Jalr,Con_Jal,Mem,OpI,Con_AUIPC,Con_LUI;
logic MemAddr, MemData, MemDataOut;
assign adr = 0;
assign din  = 0;
assign dout = 0;

instruction_memory      inst(clk, we, adr, din, instruction);
decode                  decoder(instruction, rs1, rs2, rd, opcode, funct3, funct7, i_type_imm, s_type_imm, b_type_imm, u_type_imm, j_type_imm);
int_regfile             regfile(clk, reset,rs1,rs2,waddr_in, wdata_in, RegWrite, rdata_out1, rdata_out2);
alu_mux                 alumux(rdata_out2, imm, alusrc, aluin2);
immediate_generator     immgen(instruction,imm);
alu                     ALU(rdata_out1, aluin2, aluop, alu_output);
alu_control             aluctr(aluop, funct7, funct3, aluoperation);
controller              control_unit(opcode, alusrc, MemtoReg,RegtoMem ,RegWrite, MemRead, MemWrite, Branch, aluop, Con_Jalr,
                                     Con_Jal, Mem, OpI, Con_AUIPC, Con_LUI);
data_memory             Data_mem(clk, MemWrite, MemAddr, MemData, MemDataOut);
endmodule
