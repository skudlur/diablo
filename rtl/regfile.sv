/*
*	Integer Register file module for diablo
*/


module int_regfile #parameter(XLEN=64) ( input logic clk,
		       input logic rst,
		       
		       input logic [4:0] raddr_in1,
		       input logic [4:0] raddr_in2,
		       input logic [4:0] waddr_in,
		       input logic [XLEN-1:0] wdata_in,
		       input logic wen_in,

		       output logic [XLEN-1:0] rdata_out1,
		       output logic [XLEN-1:0] rdata_out2,
);
	reg [XLEN-1:0] x0 = 0, x1, x2, x3, x4, x5, x6, x7, x8, x9;
	reg [XLEN-1:0] x10, x11, x12, x13, x14, x15, x16, x17, x18, x19;
	reg [XLEN-1:0] x20, x21, x22, x23, x24, x25, x26, x27, x28, x29, x30, x31;

	logic write_fault = 1'b0;
	
	always @(*) begin
		case (raddr_in1)
			5'b0_0000: rdata_out1 <= x0;
			5'b0_0001: rdata_out1 <= x1;
			5'b0_0010: rdata_out1 <= x2;
			5'b0_0011: rdata_out1 <= x3;
			5'b0_0100: rdata_out1 <= x4;
			5'b0_0101: rdata_out1 <= x5;
			5'b0_0110: rdata_out1 <= x6;
			5'b0_0111: rdata_out1 <= x7;
			5'b0_1000: rdata_out1 <= x8;
			5'b0_1001: rdata_out1 <= x9;
			5'b0_1010: rdata_out1 <= x10;
			5'b0_1011: rdata_out1 <= x11;
			5'b0_1100: rdata_out1 <= x12;
			5'b0_1101: rdata_out1 <= x13;
			5'b0_1110: rdata_out1 <= x14;
			5'b0_1111: rdata_out1 <= x15;
			5'b1_0000: rdata_out1 <= x16;
			5'b1_0001: rdata_out1 <= x17;
			5'b1_0010: rdata_out1 <= x18;
			5'b1_0011: rdata_out1 <= x19;
			5'b1_0100: rdata_out1 <= x20;
			5'b1_0101: rdata_out1 <= x21;
			5'b1_0110: rdata_out1 <= x22;
			5'b1_0111: rdata_out1 <= x23;
			5'b1_1000: rdata_out1 <= x24;
			5'b1_1001: rdata_out1 <= x25;
			5'b1_1010: rdata_out1 <= x26;
			5'b1_1011: rdata_out1 <= x27;
			5'b1_1100: rdata_out1 <= x28;
			5'b1_1101: rdata_out1 <= x29;
			5'b1_1110: rdata_out1 <= x30;
			5'b1_1111: rdata_out1 <= x31;
			default: rdata_out1 <= x0;
		endcase
	end

	always @(*) begin
		case (raddr_in2)
			5'b0_0000: rdata_out2 <= x0;
			5'b0_0001: rdata_out2 <= x1;
			5'b0_0010: rdata_out2 <= x2;
			5'b0_0011: rdata_out2 <= x3;
			5'b0_0100: rdata_out2 <= x4;
			5'b0_0101: rdata_out2 <= x5;
			5'b0_0110: rdata_out2 <= x6;
			5'b0_0111: rdata_out2 <= x7;
			5'b0_1000: rdata_out2 <= x8;
			5'b0_1001: rdata_out2 <= x9;
			5'b0_1010: rdata_out2 <= x10;
			5'b0_1011: rdata_out2 <= x11;
			5'b0_1100: rdata_out2 <= x12;
			5'b0_1101: rdata_out2 <= x13;
			5'b0_1110: rdata_out2 <= x14;
			5'b0_1111: rdata_out2 <= x15;
			5'b1_0000: rdata_out2 <= x16;
			5'b1_0001: rdata_out2 <= x17;
			5'b1_0010: rdata_out2 <= x18;
			5'b1_0011: rdata_out2 <= x19;
			5'b1_0100: rdata_out2 <= x20;
			5'b1_0101: rdata_out2 <= x21;
			5'b1_0110: rdata_out2 <= x22;
			5'b1_0111: rdata_out2 <= x23;
			5'b1_1000: rdata_out2 <= x24;
			5'b1_1001: rdata_out2 <= x25;
			5'b1_1010: rdata_out2 <= x26;
			5'b1_1011: rdata_out2 <= x27;
			5'b1_1100: rdata_out2 <= x28;
			5'b1_1101: rdata_out2 <= x29;
			5'b1_1110: rdata_out2 <= x30;
			5'b1_1111: rdata_out2 <= x31;
			default: rdata_out2 <= x0;
		endcase
	end

	always @(posedge clk) begin
		if (rst == 1) begin
			x1 <= 0;
			x2 <= 0;
			x3 <= 0;
			x4 <= 0;
			x5 <= 0;
			x6 <= 0;
			x7 <= 0;
			x8 <= 0;
			x9 <= 0;
			x10 <= 0;
			x11 <= 0;
			x12 <= 0;
			x13 <= 0;
			x14 <= 0;
			x15 <= 0;
			x16 <= 0;
			x17 <= 0;
			x18 <= 0;
			x19 <= 0;
			x20 <= 0;
			x21 <= 0;
			x22 <= 0;
			x23 <= 0;
			x24 <= 0;
			x25 <= 0;
			x26 <= 0;
			x27 <= 0;
			x28 <= 0;
			x29 <= 0;
			x30 <= 0;
			x31 <= 0;
		end
		else if (wen_in) begin
			case (waddr_in)
				5'b0_0000: x0 <= wdata_in;
				5'b0_0001: x1 <= wdata_in;
				5'b0_0010: x2 <= wdata_in;
				5'b0_0011: x3 <= wdata_in;
				5'b0_0100: x4 <= wdata_in;
				5'b0_0101: x5 <= wdata_in;
				5'b0_0110: x6 <= wdata_in;
				5'b0_0111: x7 <= wdata_in;
				5'b0_1000: x8 <= wdata_in;
				5'b0_1001: x9 <= wdata_in;
				5'b0_1010: x10 <= wdata_in;
				5'b0_1011: x11 <= wdata_in;
				5'b0_1100: x12 <= wdata_in;
				5'b0_1101: x13 <= wdata_in;
				5'b0_1110: x14 <= wdata_in;
				5'b0_1111: x15 <= wdata_in;
				5'b1_0000: x16 <= wdata_in;
				5'b1_0001: x17 <= wdata_in;
				5'b1_0010: x18 <= wdata_in;
				5'b1_0011: x19 <= wdata_in;
				5'b1_0100: x20 <= wdata_in;
				5'b1_0101: x21 <= wdata_in;
				5'b1_0110: x22 <= wdata_in;
				5'b1_0111: x23 <= wdata_in;
				5'b1_1000: x24 <= wdata_in;
				5'b1_1001: x25 <= wdata_in;
				5'b1_1010: x26 <= wdata_in;
				5'b1_1011: x27 <= wdata_in;
				5'b1_1100: x28 <= wdata_in;
				5'b1_1101: x29 <= wdata_in;
				5'b1_1110: x30 <= wdata_in;
				5'b1_1111: x31 <= wdata_in;
				default: write_fault <= 1'b1;
			endcase
		end
	end	
endmodule
