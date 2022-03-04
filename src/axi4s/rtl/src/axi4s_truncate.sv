module axi4s_truncate
  import axi4s_pkg::*;
( 
  axi4s_intf.rx       rx_axis,
  axi4s_intf.tx       tx_axis,
  input logic [15:0]  length
);

   logic [63:0] tkeep;
   logic [15:0] word_count;

   always @(posedge rx_axis.aclk) begin
      if (rx_axis.tvalid & rx_axis.tready) begin
	 if (rx_axis.sop) begin
	    word_count <= length[15:6];
	 end else begin
	    word_count <= word_count - 1;
	 end
      end
   end

   assign tx_axis.aclk   = rx_axis.aclk;
   assign tx_axis.aresetn= rx_axis.aresetn;

   assign tx_axis.tvalid = rx_axis.tvalid;
   assign tx_axis.tkeep  = rx_axis.tkeep;
   assign tx_axis.tlast  = rx_axis.tlast;   
   assign rx_axis.tready = tx_axis.tready;
   
   assign tx_axis.tdata  = rx_axis.tdata;
   assign tx_axis.tid    = rx_axis.tid;
   assign tx_axis.tdest  = rx_axis.tdest;
   assign tx_axis.tuser  = rx_axis.tuser;
   

endmodule // axi4s_truncator
