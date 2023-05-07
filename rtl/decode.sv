module riscv_decode (
  input		logic[31:0] instruction,
  output	logic[4:0]	rs1,
  output	logic[4:0]  rs2,
  output	logic[4:0]  rd,
  output 	logic[6:0]	opcode,
  output	logic[2:0]  funct3,
  output	logic[6:0]  funct7,
  output  logic[11:0] i_type_imm,
  output  logic[11:0] s_type_imm,
  output  logic[11:0] b_type_imm,
  output  logic[19:0] u_type_imm,
  output  logic[19:0] j_type_imm
);
always_comb
   begin
      case(instruction[6:0])
         7'b0110011 : begin  rs1 = instruction[19:15];
                             rs2 = instruction[24:20];
                             rd = instruction[11:7];   
                             funct3 = instruction[14:12];
                             funct7 = instruction[31:25];
                             opcode = instruction[6:0]; end 
         7'b0010011 : begin  rs1 = instruction[19:15];
                             funct3 = instruction[14:12];
                             rd = instruction[11:7];
                             i_type_imm = instruction[31:20];
                             opcode = instruction[6:0]; end
         7'b0100011 : begin  rs2 = instruction[24:20];
                             rs1 = instruction[19:15];
                             funct3 = instruction[14:12];
                             s_type_imm = {instruction[31:25],instruction[11:7]};
                             opcode = instruction[6:0]; end
         7'b1100111 : begin  funct3 = instruction[14:12];
                             rs1 = instruction[19:15];
                             rs2 = instruction[24:20];
                             b_type_imm = {instruction[31],instruction[7],instruction[30:25]};
                             opcode = instruction[6:0]; end
         7'b1101111 : begin  rd = instruction[11:7];
                             u_type_imm = {instruction[31],instruction[19:12],instruction[20],instruction[30:21]};
                             opcode = instruction[6:0]; end
         7'b0110111 : begin  rd = instruction[11:7];
                             j_type_imm = instruction[31:12];
                             opcode = instruction[6:0]; end
         7'b1110011 : begin  rs1 = instruction[19:15];
                             funct3 = instruction[14:12];
                             rd = instruction[11:7];
                             i_type_imm = instruction[31:20];
                             opcode = instruction[6:0]; end
      endcase
   end
endmodule
