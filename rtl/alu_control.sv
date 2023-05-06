/* ALU Control Unit performs operations to determine the set of bits that would invigorate the ALU to enable
   a desired arithmetic/logical hardware unit to perform the same. */
module alu_control #(parameter N=4)(aluop,funct7,funct3,aluoperation); //variables instantiated for functional operation
input logic  [N-3:0]aluop; //ALUop fed from main control uit
input logic  funct7; // funct7[30]
input logic  [N-2:0]funct3; //funct3[14:12]
output logic [N-1:0]aluoperation; //ALUoperation fed into the ALU Unit
always @ (*) //senses any input
   begin
        casex({funct7,funct3,aluop}) //incorporates don't cares
           6'bxxxx00 : aluoperation = 4'b0010; //Addition wrt Load/Store
           6'bxxxx01 : aluoperation = 4'b0110; //Subtraction wrt Branch
           6'b000010 : aluoperation = 4'b0010; //Addition
           6'b100010 : aluoperation = 4'b0110; //Subtraction
           6'b011110 : aluoperation = 4'b0000; //AND-ing
           6'b011010 : aluoperation = 4'b0001; //OR-ing
        endcase
   end
endmodule


