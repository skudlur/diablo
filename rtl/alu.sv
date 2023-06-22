/*
*	Arithmetic Logical Unit for Diablo     
*/

module alu #(parameter XLEN = 64)( 
  	input logic [XLEN-1:0] alu_input1, alu_input2,
  	input logic [3:0] operation,                       //More to be added  
  	output logic [XLEN-1:0] alu_output
);
  	always_comb 
  	begin  
    		case(operation)
    			4'b0000:alu_output = 64'b0;
    			4'b0001: alu_output = alu_input1 + alu_input2; 
		    	4'b0010: alu_output = alu_input1 - alu_input2;
		    	4'b0011: alu_output = alu_input1 * alu_input2;
		    	4'b0100: alu_output = alu_input1 | alu_input2;
		    	4'b0101: alu_output = alu_input1 ^ alu_input2;
		    	4'b0110: alu_output = alu_input1 < alu_input2;
		    	4'b0111: alu_output = alu_input1 > alu_input2;
		    	4'b1000: alu_output = alu_input1 / alu_input2;
		    	default: alu_output = 0;
		endcase 
  	end
endmodule
