module ALU( ALU_Input1,ALU_Input2,ALU_Output,Signal);
  
  
  
  input logic [63:0] ALU_Input1,ALU_Input2;
  input logic [1:0]Signal;                       //More to be added  
  output logic [63:0]ALU_Output;
    
  always_comb 
  begin
    
    case(Signal)
    2'b00: ALU_Output = ALU_Input1 + ALU_Input2; 
    2'b01: ALU_Output = ALU_Input1 - ALU_Input2;
    default: ALU_Output = 64'b0;
    endcase 
 
  end
   
    
    
endmodule
