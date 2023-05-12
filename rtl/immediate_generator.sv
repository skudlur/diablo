module immediate_generator #parameter(XLEN=64) (
	input logic [31:0]instruction,
	output logic [XLEN-1:0]immout
);
	logic [6:0]opcode;
	logic [3:0]func3;

	assign opcode = instruction[6:0];
	assign func3 = instruction[14:12];

	always_comb
    	begin 
         	case(opcode)
            		7'b0010011: immout = { {53{instruction[31]}}, instruction[30:25], instruction[24:21], instruction[20]};                                  // I- Type(ADDI)
            		7'b0100011: immout = { {53{instruction[31]}}, instruction[30:25], instruction[11:8], instruction[7]};                                    // S- Type
            		7'b0010111: immout = { instruction[31], instruction[30:20], instruction[19:12], {44{1'b0}} };                                            // U- Type
            		7'b0000011: immout = { {53{instruction[31]}}, instruction[30:25], instruction[24:21], instruction[20]};                                  // I- Type(LW)
            		7'b1101111: immout = { {44{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:25], instruction[24:21], {1{1'b0}}};   // J- Type
            		7'b1100011: immout = { {52{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], {1{1'b0}}};                         // B- Type
            		default: immout = X;
         	endcase
    	end
endmodule
