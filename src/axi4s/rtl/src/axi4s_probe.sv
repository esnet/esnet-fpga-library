// axi4s_probe module used to monitor an axi4s interface via the regmap
module axi4s_probe
   import axi4s_pkg::*;
#(
   parameter axi4s_probe_mode_t MODE = GOOD,
   parameter axi4s_tuser_mode_t TUSER_MODE = USER
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
   logic incr_en;

   initial incr_en = 1'b0;
   always @(posedge axi4s_if.aclk) begin
      case (MODE)
         GOOD:    incr_en <= ( axi4s_if.tready && axi4s_if.tvalid);
         OVFL:    incr_en <= (!axi4s_if.tready && axi4s_if.tvalid);
         ERRORS:  incr_en <= ( axi4s_if.tready && axi4s_if.tvalid);  // see below for pkt_error handling.
         default: incr_en <= 1'b0;
      endcase
   end

   logic  pkt_error;
   always @(posedge axi4s_if.aclk) pkt_error <= (TUSER_MODE == PKT_ERROR) && axi4s_if.tuser;

   logic                     axi4s_if_aresetn_p;
   logic                     axi4s_if_tvalid_p;
   logic                     axi4s_if_tready_p;
   logic [DATA_BYTE_WID-1:0] axi4s_if_tkeep_p;
   logic                     axi4s_if_tlast_p;
   always_ff @(posedge axi4s_if.aclk) begin
       axi4s_if_aresetn_p <= axi4s_if.aresetn;
       axi4s_if_tvalid_p <= axi4s_if.tvalid;
       axi4s_if_tready_p <= axi4s_if.tready;
       axi4s_if_tkeep_p <= axi4s_if.tkeep;
       axi4s_if_tlast_p <= axi4s_if.tlast;
    end
   
   logic        pkt_cnt_incr;
   logic        pkt_cnt_incr_p;

   logic [7:0]  byte_cnt_incr;
   logic [15:0] byte_cnt_int;
   logic        byte_cnt_int_val;

   logic [55:0] byte_cnt;
   logic [55:0] byte_cnt_base;

   logic [49:0] pkt_cnt;
   logic [49:0] pkt_cnt_base;

   logic        disable_update;
   logic        disable_update_p;

   logic        clear_evt;

   assign clear_evt = !axi4l_to_regif__axi4s_aclk.aresetn || (reg_if.probe_control_wr_evt && (reg_if.probe_control.clear == '1));  // CLR_ON_WR_EVT

   assign byte_cnt_base = clear_evt ? '0 : byte_cnt;
   assign  pkt_cnt_base = clear_evt ? '0 :  pkt_cnt;

   assign byte_cnt_int_val = pkt_cnt_incr_p;

   initial begin
       pkt_cnt_incr = 1'b0;
       pkt_cnt_incr_p = 1'b0;
       byte_cnt_incr = '0;
       disable_update = 1'b0;
       disable_update_p = 1'b0;
       byte_cnt_int = '0;
       pkt_cnt = '0;
       byte_cnt = '0;
   end
   always @(posedge axi4s_if.aclk) 
      begin
         pkt_cnt_incr    <= incr_en && axi4s_if_tlast_p;
         pkt_cnt_incr_p  <= pkt_cnt_incr;

         byte_cnt_incr <= incr_en ? count_ones(axi4s_if_tkeep_p) : '0;

         // if counting ERRORS, disable byte_cnt update if NO pkt_error is detected on tlast.
         // else (if counting GOOD pkts), disable byte_cnt update if PKT_ERROR is detected on tlast.
         if (MODE == ERRORS) disable_update <= incr_en && axi4s_if_tlast_p && !pkt_error;
         else                disable_update <= incr_en && axi4s_if_tlast_p &&  pkt_error;

         disable_update_p <= disable_update;

         if (byte_cnt_int_val) byte_cnt_int <= {8'd0, byte_cnt_incr};  // reset intermediate byte cnt at end of pkt.
         else                  byte_cnt_int <= (byte_cnt_int + {8'd0, byte_cnt_incr});

         if (disable_update_p)      pkt_cnt <= pkt_cnt_base;
         else                       pkt_cnt <= pkt_cnt_base + {49'd0, pkt_cnt_incr_p};

         if (disable_update_p)      byte_cnt <= byte_cnt_base;
         else if (byte_cnt_int_val) byte_cnt <= byte_cnt_base + {40'd0, byte_cnt_int};
         else                       byte_cnt <= byte_cnt_base;

       end 

   // register read interface connections
   assign reg_if.pkt_count_upper_nxt  =  {14'd0,  pkt_cnt[49:32] };
   assign reg_if.pkt_count_lower_nxt  =           pkt_cnt[31:0];
   assign reg_if.byte_count_upper_nxt =  { 8'd0, byte_cnt[55:32] };
   assign reg_if.byte_count_lower_nxt =          byte_cnt[31:0];

   always_comb begin
      if (reg_if.probe_control.latch == '1) begin  // LATCH_ON_WR_EVT
         reg_if.pkt_count_upper_nxt_v  = reg_if.probe_control_wr_evt ? 1'b1 : 1'b0;
         reg_if.pkt_count_lower_nxt_v  = reg_if.probe_control_wr_evt ? 1'b1 : 1'b0;
         reg_if.byte_count_upper_nxt_v = reg_if.probe_control_wr_evt ? 1'b1 : 1'b0;
         reg_if.byte_count_lower_nxt_v = reg_if.probe_control_wr_evt ? 1'b1 : 1'b0;
      end else begin // LATCH_ON_CLK
         reg_if.pkt_count_upper_nxt_v  = 1'b1;
         reg_if.pkt_count_lower_nxt_v  = 1'b1;
         reg_if.byte_count_upper_nxt_v = 1'b1;
         reg_if.byte_count_lower_nxt_v = 1'b1;
      end
   end

   // Control signal monitoring
   assign reg_if.monitor_nxt_v = 1'b1;
   assign reg_if.monitor_nxt.aresetn = axi4s_if_aresetn_p;
   assign reg_if.monitor_nxt.tvalid  = axi4s_if_tvalid_p;
   assign reg_if.monitor_nxt.tready  = axi4s_if_tready_p;
   assign reg_if.monitor_nxt.tlast   = axi4s_if_tlast_p;

   // Control signal activity tracking
   struct packed {logic tvalid; logic tready; logic tlast;} activity;

   always_comb begin
      if (reg_if.activity_rd_evt) activity = '0;
      else begin
          activity.tvalid = reg_if.activity.tvalid || axi4s_if_tvalid_p;
          activity.tready = reg_if.activity.tready || axi4s_if_tready_p;
          activity.tlast  = reg_if.activity.tlast  || axi4s_if_tlast_p;
      end
   end
   assign reg_if.activity_nxt_v = 1'b1;
   assign reg_if.activity_nxt.tvalid = activity.tvalid;
   assign reg_if.activity_nxt.tready = activity.tready;
   assign reg_if.activity_nxt.tlast  = activity.tlast;

endmodule
