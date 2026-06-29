// Copyright (c) 2019 Bluespec, Inc. All Rights Reserved.
// Author: Rishiyur S. Nikhil

package AXI4_Mem_Model;

// ================================================================
// A memory-model to be used as a slave on an AXI4 bus.
// Only partical functionality; will be gradually improved over time.
// Current status:
//     Address and Data bus widths: 64b
//     Bursts:      'fixed' and 'incr' only
//     Size:        Full 64-bit width reads/writes only
//     Strobes:     Not yet handled
//     memory size: See 'mem_size_word64' definition below

// ================================================================
// Exports

export AXI4_Dual_Mem_Model_IFC (..);
export mkAXI4_Mem_Model;

// ================================================================
// Bluespec library imports

import RegFile      :: *;
import FIFOF        :: *;
import GetPut       :: *;
import ClientServer :: *;

// ----------------
// BSV additional libs

import Cur_Cycle  :: *;
import GetPut_Aux :: *;
import Semi_FIFOF :: *;

// ================================================================
// Project imports

import AXI4_Types :: *;

// ================================================================
// INTERFACE

interface AXI4_Dual_Mem_Model_IFC #(numeric type  wd_id,
			       numeric type  wd_addr,
			       numeric type  wd_data,
			       numeric type  wd_user);
   method Action init (Bit #(wd_addr) addr_map_base, Bit #(wd_addr) addr_map_lim);

   interface AXI4_Slave_IFC #(wd_id, wd_addr, wd_data, wd_user) slave_imem;
   interface AXI4_Slave_IFC #(wd_id, wd_addr, wd_data, wd_user) slave_dmem;
endinterface

// ================================================================
// IMPLEMENTATION

Integer mem_size_word64 = 'h200_0000;    // 32M x 64b words = 256MiB

function Bool fn_addr_ok (Bit #(64) base, Bit #(64) lim, Bit #(64) addr, AXI4_Size size);
   let aligned  = fn_addr_is_aligned (addr, size);
   let in_range = ((base <= addr) && (addr < lim));
   return (aligned && in_range);
endfunction

// ----------------

module mkAXI4_Mem_Model (AXI4_Dual_Mem_Model_IFC #(wd_id, wd_addr, wd_data, wd_user))
   provisos (NumAlias #(wd_addr, 64),
	     NumAlias #(wd_data, 64));

   // 0 = quiet; 1 = show mem transactions
   Integer verbosity = 1;

   Reg #(Bool) rg_initialized <- mkReg (False);

   Reg #(Bit #(wd_addr)) rg_addr_map_base <- mkRegU;
   Reg #(Bit #(wd_addr)) rg_addr_map_lim  <- mkRegU;

   AXI4_Slave_Xactor_IFC #(wd_id, wd_addr, wd_data, wd_user) xactor_i <- mkAXI4_Slave_Xactor;
   AXI4_Slave_Xactor_IFC #(wd_id, wd_addr, wd_data, wd_user) xactor_d <- mkAXI4_Slave_Xactor;

   RegFile #(Bit #(wd_addr), Bit #(wd_data)) rf <- mkRegFileLoad ("mem.hex", 0, fromInteger (mem_size_word64));

   // ================================================================
   // Read requests IMEM

   Reg #(Bit #(8)) rg_rd_beat_i <- mkReg (0);

   rule rl_read_i (rg_initialized);
      let rd_addr  = xactor_i.o_rd_addr.first;
      let rf_index = ((rd_addr.araddr - rg_addr_map_base) >> 3);
      if (rd_addr.arburst == axburst_incr)
	 rf_index = rf_index + zeroExtend (rg_rd_beat_i);
      let last = (rg_rd_beat_i == rd_addr.arlen);

      let addr_ok = fn_addr_ok (rg_addr_map_base, rg_addr_map_lim, rd_addr.araddr, rd_addr.arsize);
      Bit #(64) rd_data = 0;
      if (addr_ok)
	 rd_data = rf.sub (rf_index);

      AXI4_Rd_Data #(wd_id, wd_data, wd_user) rd_resp = ?;
      rd_resp = AXI4_Rd_Data {rid:   rd_addr.arid,
			      rdata: rd_data,
			      rresp: (addr_ok ? axi4_resp_okay : axi4_resp_slverr),
			      rlast: last,
			      ruser: rd_addr.aruser};
      xactor_i.i_rd_data.enq (rd_resp);

      if (last) begin
	 xactor_i.o_rd_addr.deq;
	 rg_rd_beat_i <= 0;
      end
      else
	 rg_rd_beat_i <= rg_rd_beat_i + 1;
      $display("cycle %0d: rl_read_i addr=%0h data=%0h", cur_cycle, rd_addr.araddr, rd_data);
   endrule

   // ================================================================
   // Read requests DMEM

   Reg #(Bit #(8)) rg_rd_beat_d <- mkReg (0);

   rule rl_read_d (rg_initialized);
      let rd_addr  = xactor_d.o_rd_addr.first;
      let rf_index = ((rd_addr.araddr - rg_addr_map_base) >> 3);
      if (rd_addr.arburst == axburst_incr)
	 rf_index = rf_index + zeroExtend (rg_rd_beat_d);
      let last = (rg_rd_beat_d == rd_addr.arlen);

      let addr_ok = fn_addr_ok (rg_addr_map_base, rg_addr_map_lim, rd_addr.araddr, rd_addr.arsize);
      Bit #(64) rd_data = 0;
      if (addr_ok)
	 rd_data = rf.sub (rf_index);

      AXI4_Rd_Data #(wd_id, wd_data, wd_user) rd_resp = ?;
      rd_resp = AXI4_Rd_Data {rid:   rd_addr.arid,
			      rdata: rd_data,
			      rresp: (addr_ok ? axi4_resp_okay : axi4_resp_slverr),
			      rlast: last,
			      ruser: rd_addr.aruser};
      xactor_d.i_rd_data.enq (rd_resp);

      if (last) begin
	 xactor_d.o_rd_addr.deq;
	 rg_rd_beat_d <= 0;
      end
      else
	 rg_rd_beat_d <= rg_rd_beat_d + 1;
      $display("cycle %0d: rl_read_d addr=%0h data=%0h", cur_cycle, rd_addr.araddr, rd_data);
   endrule

   // ================================================================
   // Write requests DMEM

   Reg #(Bit #(8)) rg_wr_beat_d <- mkReg (0);

   rule rl_write_d (rg_initialized);
      let wr_addr = xactor_d.o_wr_addr.first;
      let wr_data <- pop_o (xactor_d.o_wr_data);
      let rf_index   = ((wr_addr.awaddr - rg_addr_map_base) >> 3);
      if (wr_addr.awburst == axburst_incr)
	 rf_index = rf_index + zeroExtend (rg_wr_beat_d);
      let last = (rg_wr_beat_d == wr_addr.awlen);

      let addr_ok = fn_addr_ok (rg_addr_map_base, rg_addr_map_lim, wr_addr.awaddr, wr_addr.awsize);

      Bit#(64) new_data = 0;
      if (addr_ok) begin
         let old_data = rf.sub (rf_index);
         Bit #(64) mask = 0;
         for (Integer i = 0; i < 8; i = i + 1) begin
            if (wr_data.wstrb[i] == 1'b1) begin
               mask[(i*8)+7 : i*8] = 8'hFF;
            end
         end
         new_data = (old_data & (~mask)) | (wr_data.wdata & mask);
	 rf.upd (rf_index, new_data);
      end
      $display("cycle %0d: rl_write_d addr=%0h wdata=%0h wstrb=%0h new_data=%0h", cur_cycle, wr_addr.awaddr, wr_data.wdata, wr_data.wstrb, new_data);

      if (last) begin
	 AXI4_Wr_Resp #(wd_id, wd_user) wr_resp = ?;
	 wr_resp = AXI4_Wr_Resp {bid:   wr_addr.awid,
				 bresp: (addr_ok ? axi4_resp_okay : axi4_resp_slverr),
				 buser: wr_addr.awuser};
	 xactor_d.i_wr_resp.enq (wr_resp);
	 xactor_d.o_wr_addr.deq;
	 rg_wr_beat_d <= 0;
      end
      else
	 rg_wr_beat_d <= rg_wr_beat_d + 1;
   endrule

   // ================================================================
   // INTERFACE

   method Action init (Bit #(wd_addr) addr_map_base, Bit #(wd_addr) addr_map_lim);
      if (addr_map_base [2:0] != 3'b0)
	 $display ("%0d: %m.init: ERROR: unaligned addr_map_base 0x%0h", cur_cycle, addr_map_base);
      else if ((addr_map_lim - addr_map_base) > fromInteger (mem_size_word64 * 8))
	 $display ("%0d: %m.init: ERROR: mem size (base 0x%0h, lim 0x%0h) > max (0x%0h)",
		   cur_cycle,
		   addr_map_base,
		   addr_map_lim,
		   fromInteger (mem_size_word64 * 8));
      else begin
	 xactor_i.reset;
	 xactor_d.reset;
	 rg_addr_map_base <= addr_map_base;
	 rg_addr_map_lim  <= addr_map_lim;
	 rg_initialized   <= True;
	 $display ("%0d: %m.init: addr_map_base 0x%0h, addr_map_lim 0x%0h",
		   cur_cycle,
		   addr_map_base,
		   addr_map_lim);
      end
   endmethod
   interface slave_imem = xactor_i.axi_side;
   interface slave_dmem = xactor_d.axi_side;
endmodule

// ================================================================

endpackage
