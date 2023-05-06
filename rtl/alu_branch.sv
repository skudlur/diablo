`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.05.2023 10:36:21
// Design Name: 
// Module Name: alu_branch
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module alu_branch(pccurrent,pcoffset,updatedpc);
input logic [63:0]pccurrent;
input logic [63:0]pcoffset;
output logic [63:0]updatedpc;
assign updatedpc = pccurrent + pcoffset;
endmodule

module alu_branch(

    );
endmodule
