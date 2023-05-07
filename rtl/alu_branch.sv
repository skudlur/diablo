module alu_branch #parameter(XLEN=64) (
	input logic [XLEN-1:0] pccurrent,
	input logic [XLEN-1:0] pcoffset,
	output logic [XLEN-1:0] updatedpc
};
	assign updatedpc = pccurrent + pcoffset;
endmodule

