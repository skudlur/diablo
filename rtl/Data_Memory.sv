module Data_Memory #(parameter N=6,M=64)
(input logic clk,
input logic we,
input logic[N-1:0]adr,
input logic[M-1:0]din,
output logic[M-1:0]dout);

logic[M-1:0]mem[2**N-1:0];

always_ff@(posedge clk)
    if(we) mem[adr] <= din;
    
    assign dout = mem[adr];
    
endmodule
