`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05.05.2023 22:50:32
// Design Name: 
// Module Name: alu_control\
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
module alu_control #(parameter N=4)(a,b,c,d); //variables instantiated for functional operation
input logic [N-3:0]a; //ALUop fed from main control uit
input logic b; // funct7[30]
input logic [N-2:0]c; //funct3[14:12]
output logic [N-1:0]d; //ALUoperation fed into the ALU Unit
always @ (*) //senses any input
begin
casex({b,c,a}) //incorporates don't cares
6'bxxxx00: d=4'b0010; //Addition wrt Load/Store
6'bxxxx01: d=4'b0110; //Subtraction wrt Branch
6'b000010: d=4'b0010; //Addition
6'b100010: d=4'b0110; //Subtraction
6'b011110: d=4'b0000; //AND-ing
6'b011010: d=4'b0001; //OR-ing
endcase
end
endmodule


