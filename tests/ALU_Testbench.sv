`timescale 1ns / 1ps

module ALU_Testbench();

logic [63:0]input1,input2,ALU_out;
logic [1:0]Signal;

ALU DUT(input1, input2, ALU_out, Signal);

initial begin
input1 = 64'd1; input2 = 64'd0; Signal = 2'd0; #10;
input1 = 64'd2; input2 = 64'd2; Signal = 2'd1; #10;
input1 = 64'd1; input2 = 64'd3; Signal = 2'd0; #10;
input1 = 64'd4; input2 = 64'd0; Signal = 2'd0; #10;
input1 = 64'd1; input2 = 64'd7; Signal = 2'd0; #10;
input1 = 64'd5; input2 = 64'd6; Signal = 2'd0; #10;
input1 = 64'd9; input2 = 64'd0; Signal = 2'd0; #10;
input1 = 64'd1; input2 = 64'd8; Signal = 2'd0; #10;
end


endmodule
