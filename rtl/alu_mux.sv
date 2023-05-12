module alu_mux #(parameter XLEN=64) ( 
	input logic [XLEN-1:0] reg2,
	input logic [XLEN-1:0] imm,
	input logic control,
	output logic [XLEN-1:0] aluin2
);
    assign aluin2 = control ? reg2 : imm;
endmodule




