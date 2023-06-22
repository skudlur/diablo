module data_memory #(parameter N=6,M=64) (
	input logic clk,
	input logic we,
	input logic [N-1:0] adr,
	input logic [M-1:0] din,
	output logic [M-1:0] dout
);

logic[M-1:0]mem[2**N-1:0];

always_ff@(posedge clk) 
    begin
        if(we)
        begin 
        mem[adr] <= din;
        end
        else
        begin
        dout <= mem[adr];
        end
    end
endmodule