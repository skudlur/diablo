/*
*	Arithmetic Logical Unit for Diablo
*/

module alu (
  input logic [31:0]  alu_input1, alu_input2,
  input logic [6:0] alu_op,
  output logic [31:0] alu_output
);

   `include "diablo_pkg.sv";

   always_comb
   begin
     unique case(alu_op)
       // Arithmetic operations

       `ALU_ADD: alu_output = alu_input1 + alu_input2;                                        // Add instruction
       `ALU_SUB: alu_output = alu_input1 - alu_input2;                                        // Sub instruction
       `ALU_AND: alu_output = alu_input1 & alu_input2;                                        // AND instruction
       `ALU_OR : alu_output = alu_input1 | alu_input2;                                        // OR instruction
       `ALU_XOR: alu_output = alu_input1 ^ alu_input2;                                        // XOR instruction

       // Shift operations

       `ALU_SLL: alu_output = alu_input1 << (alu_input2 & 5'b11111);                           // Shift left logical instruction
       `ALU_SRL: alu_output = alu_input1 >> (alu_input2 & 5'b11111);                           // Shift right logical instruction
       `ALU_SRA: alu_output = $signed(alu_input1) >> (alu_input2 & 5'b11111);                  // Shift right arithmetic instruction

       // Logical operations

       `ALU_SLT: alu_output = ($signed(alu_input1) < $signed(alu_input2)) ? 32'b1 : 32'b0;    // Set if less than
       `ALU_SLTU: alu_output = (alu_input1 < alu_input2) ? 32'b1 : 32'b0;                     // Set if less than unsigned
       default: alu_output = 0;
     endcase
   end
endmodule
