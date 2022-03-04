// =============================================================================
//  NOTICE: This computer software was prepared by The Regents of the
//  University of California through Lawrence Berkeley National Laboratory
//  and Jonathan Sewter hereinafter the Contractor, under Contract No.
//  DE-AC02-05CH11231 with the Department of Energy (DOE). All rights in the
//  computer software are reserved by DOE on behalf of the United States
//  Government and the Contractor as provided in the Contract. You are
//  authorized to use this computer software for Governmental purposes but it
//  is not to be released or distributed to the public.
//
//  NEITHER THE GOVERNMENT NOR THE CONTRACTOR MAKES ANY WARRANTY, EXPRESS OR
//  IMPLIED, OR ASSUMES ANY LIABILITY FOR THE USE OF THIS SOFTWARE.
//
//  This notice including this sentence must appear on any copies of this
//  computer software.
// =============================================================================

// axi4s_probe module used to monitor an axi4s interface via the regmap
module axi4s_probe #(
   parameter logic DROP_COUNTS = 0
)  (
   axi4s_intf.prb          axi4s_if, 
   axi4l_intf.peripheral   axi4l_if
);

   localparam DATA_BYTE_WID  = axi4s_if.DATA_BYTE_WID;
   localparam COUNT_ONES_WID = $clog2(DATA_BYTE_WID);
   
   // count_ones function 
   function automatic logic[COUNT_ONES_WID:0] count_ones (input [DATA_BYTE_WID-1:0] tkeep);
      automatic logic[COUNT_ONES_WID:0] count = 0;
      for (int i=0; i<DATA_BYTE_WID; i++) count = count + tkeep[i];
      return count;
   endfunction


  // axil interface cdc synchronizer
   axi4l_intf axi4l_to_regif__axi4s_aclk ();

   axi4l_intf_cdc axi4l_to_regif_cdc (
      .axi4l_if_from_controller  ( axi4l_if ),
      .clk_to_peripheral         ( axi4s_if.aclk ),
      .axi4l_if_to_peripheral    ( axi4l_to_regif__axi4s_aclk )
   );

   // axi4s probe register block
   axi4s_probe_reg_intf reg_if ();
   
   axi4s_probe_reg_blk axi4s_probe_reg_blk (
      .axil_if    (axi4l_to_regif__axi4s_aclk),
      .reg_blk_if (reg_if)
   );

   // packet and byte counter logic    
   logic [49:0] pkt_count;
   logic        pkt_count_incr;

   logic [55:0] byte_count;
   logic [7:0]  byte_count_incr;

   logic        count_enable;

   assign count_enable = DROP_COUNTS ? (!axi4s_if.tready && axi4s_if.tvalid) :
                                       ( axi4s_if.tready && axi4s_if.tvalid) ;

   always @(posedge axi4s_if.aclk) 
      if (!axi4s_if.aresetn || reg_if.byte_count_lower_rd_evt) begin
         pkt_count_incr  <= 0;
         pkt_count       <= 0;
         byte_count_incr <= 0;
         byte_count      <= 0;

      end else if (!reg_if.halt_counters[0]) begin
         if (count_enable && axi4s_if.tlast) pkt_count_incr <= 1;
         else                                pkt_count_incr <= 0;

         pkt_count <= pkt_count + {49'd0, pkt_count_incr};

         if (count_enable) byte_count_incr <= count_ones(axi4s_if.tkeep);
         else              byte_count_incr <= 0;

         byte_count <= byte_count + {48'd0, byte_count_incr};
      end 

   // register read interface connections
   assign reg_if.pkt_count_upper_nxt  =  {14'd0,  pkt_count[49:32] };
   assign reg_if.pkt_count_lower_nxt  =           pkt_count[31:0];
   assign reg_if.byte_count_upper_nxt =  { 8'd0, byte_count[55:32] };
   assign reg_if.byte_count_lower_nxt =          byte_count[31:0];

   assign reg_if.pkt_count_upper_nxt_v  = 1'b1;
   assign reg_if.pkt_count_lower_nxt_v  = 1'b1;
   assign reg_if.byte_count_upper_nxt_v = 1'b1;
   assign reg_if.byte_count_lower_nxt_v = 1'b1;

endmodule
