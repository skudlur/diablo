/*
	   +----------------------------+
           |                            |
           |                            |
           |                            +---------->
           |                            |Operand 1
           |                            |
           |                            |
---------->|                            +---------->
Instruction|          Decoder           |Operand 2
           |                            |
           |                            |
           |                            +---------->
           |                            |Opcode
           |                            |
           |                            |
           |                            |
           +----------------------------+
*/

module decoder #parameter(XLEN=64) (
		input logic [XLEN-1:0] instr_in,
		output logic [4:0] rs1,
		output logic [4:0] rs2,
		output logic [6:0] opcode,
		output logic 
);

	logic [XLEN/2:0] upper_instr;
	logic [XLEN/2:0] lower_instr;

	

