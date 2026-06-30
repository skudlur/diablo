package Tb;

import DiabloTypes::*;
import DiabloCore::*;
import AXI4_Types::*;
import AXI_Widths::*;
import Fabric_Defs::*;
import AXI4_Mem_Model::*;
import Connectable::*;

(* synthesize *)
module mkTb (Empty);

    Reg#(int) cycle <- mkReg(0);
    Reg#(int) state <- mkReg(0);
    DiabloCore_IFC core <- mkDiabloCore;
    
    // Dual Mem Model
    AXI4_Dual_Mem_Model_IFC#(Wd_Id, Wd_Addr, Wd_Data, Wd_User) dual_mem <- mkAXI4_Mem_Model;
    mkConnection(core.imem_master, dual_mem.slave_imem);
    mkConnection(core.mem_master, dual_mem.slave_dmem);

    // Dummy connection for DMA Server
    AXI4_Master_Xactor_IFC#(Wd_Id_Dma, Wd_Addr_Dma, Wd_Data_Dma, Wd_User_Dma) dma_master <- mkAXI4_Master_Xactor;
    mkConnection(dma_master.axi_side, core.dma_server);

    rule init (state == 0);
        core.ma_ddr4_ready();
        
        dual_mem.init(64'h8000_0000, 64'h8000_0000 + 64'h0800_0000);
        
        core.start(64'h8000_0000);
        
`ifdef WATCH_TOHOST
        core.set_watch_tohost(True, 64'h8000_1000);
`endif
        
        state <= 1;
    endrule

    rule count_cycles (state == 1);
        cycle <= cycle + 1;
        if (cycle > 20000000) begin
            $display("TIMEOUT: DiabloCore ran for 20000000 cycles.");
            $finish;
        end
    endrule
    
    rule finish_on_tohost (state == 1);
`ifdef WATCH_TOHOST
        let tv = core.mv_tohost_value();
        if (tv != 0) begin
            if ((tv >> 1) == 0) begin
                $display("SUCCESS: Test passed at cycle %0d", cycle);
            end else begin
                $display("FAIL: Test failed with code %0d at cycle %0d", tv >> 1, cycle);
            end
            $finish;
        end
`endif
    endrule

endmodule

endpackage
