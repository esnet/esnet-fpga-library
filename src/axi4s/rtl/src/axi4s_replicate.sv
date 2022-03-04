module axi4s_replicate
  import axi4s_pkg::*;
( 
  axi4s_intf.rx       rx_axis,
  axi4s_intf.tx       tx_axis_0,
  axi4s_intf.tx       tx_axis_1
);

   logic bus_ready;
   
   assign tx_axis_0.aclk   = rx_axis.aclk;
   assign tx_axis_0.aresetn= rx_axis.aresetn;
   assign tx_axis_0.tvalid = rx_axis.tvalid & bus_ready;
   assign tx_axis_0.tdata  = rx_axis.tdata;
   assign tx_axis_0.tkeep  = rx_axis.tkeep;
   assign tx_axis_0.tlast  = rx_axis.tlast;
   assign tx_axis_0.tid    = rx_axis.tid;
   assign tx_axis_0.tdest  = rx_axis.tdest;
   assign tx_axis_0.tuser  = rx_axis.tuser;

   assign tx_axis_1.aclk   = rx_axis.aclk;
   assign tx_axis_1.aresetn= rx_axis.aresetn;
   assign tx_axis_1.tvalid = rx_axis.tvalid & bus_ready ;
   assign tx_axis_1.tdata  = rx_axis.tdata;
   assign tx_axis_1.tkeep  = rx_axis.tkeep;
   assign tx_axis_1.tlast  = rx_axis.tlast;
   assign tx_axis_1.tid    = rx_axis.tid;
   assign tx_axis_1.tdest  = rx_axis.tdest;
   assign tx_axis_1.tuser  = rx_axis.tuser;

   assign bus_ready = tx_axis_0.tready & tx_axis_1.tready;
   
   // both ports have to be ready, so this causes one egress port to block the other.
   
   assign rx_axis.tready = bus_ready;

endmodule // axi4s_replicator
