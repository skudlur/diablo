/*
*	Arithmetic Logical Unit for Diablo     
*/

module alu #(parameter XLEN = 64)( 
  	input logic [XLEN-1:0] alu_input1, alu_input2,
  	input logic [1:0] signal,                       //More to be added  
  	output logic [XLEN-1:0] alu_output
);
  	always_comb 
  	begin  
    		case(signal)
    			2'b00: alu_output = alu_input1 + alu_input2; 
		    	2'b01: alu_output = alu_input1 - alu_input2;
		    	2'b10: alu_output = alu_input1 * alu_input2;
		    	2'b11: alu_output = alu_input1 / alu_input2;
		    	default: alu_output = 0;
		endcase 
  	end
endmodule
