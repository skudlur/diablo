module top(
    input logic clk,
    input logic rst
);
    // Instantiate the Spade generated module. 
    // Spade uses escaped identifiers for namespaces.
    \diablo::main  uut(
        .clk_i(clk),
        .rst_i(rst)
    );
endmodule
