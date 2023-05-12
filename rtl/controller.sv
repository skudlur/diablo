module controller(
    
    //Input
    input logic [6:0] opcode, //7-bit opcode field from the instruction
    
    //Outputs
    output logic aluSrc,//0: The second ALU operand comes from the second register file output (Read data 2); 
                  //1: The second ALU operand is the sign-extended, lower 16 bits of the instruction.
    output logic memtoreg,regtomem, //0: The value fed to the register Write data input comes from the ALU.
                     //1: The value fed to the register Write data input comes from the data memory.
    output logic regwrite, //The register on the Write register input is written with the value on the Write data input 
    output logic memread,  //Data memory contents designated by the address input are put on the Read data output
    output logic memwrite, //Data memory contents designated by the address input are replaced by the value on the Write data input.
    output logic branch,
    output logic [1:0] aluop,
    output logic con_jalr,con_jal,mem,opi,con_auipc,con_lui

);

//    localparam r_type = 7'b0110011;
//    localparam lw     = 7'b0000011;
//    localparam sw     = 7'b0100011;
//    localparam br     = 7'b1100011;
//    localparam rtypei = 7'b0010011; //addi,ori,andi
    
    logic [6:0] r_type, lw, sw, rtypei, br, jalr, jal , auipc ,lui;
    assign  br     = 7'b1100011;
    assign  r_type = 7'b0110011;
    assign  lw     = 7'b0000011;
    assign  sw     = 7'b0100011;
    assign  rtypei = 7'b0010011; //addi,ori,andi
    assign  jal = 7'b1101111;
    assign  jalr = 7'b1100111;
    assign  auipc = 7'b0010111;
    assign  lui = 7'b0110111;

    assign con_jal = (opcode == jal);  
    assign con_jalr = (opcode == jalr);  
    assign branch = (opcode == br);  
    assign alusrc   = (opcode==lw || opcode==sw || opcode == rtypei);
    assign memtoreg = (opcode==lw);
    assign regtomem = (opcode==sw);
    assign regwrite = (opcode==r_type || opcode==lw || opcode == rtypei || opcode == jalr || opcode == jal);
    assign mem = (opcode==lw||opcode==sw);
    assign memread  = (opcode==lw);
    assign memwrite = (opcode==sw||opcode == jalr);
    assign aluop[0] = (opcode==br);
    assign opi = (opcode==rtypei);
    assign aluop[1] = (opcode==r_type);
    assign con_auipc = (opcode==auipc);
    assign con_lui = (opcode==lui);
  

endmodule
