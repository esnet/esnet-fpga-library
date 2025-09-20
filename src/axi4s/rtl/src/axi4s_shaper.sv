module axi4s_shaper
( 
  axi4s_intf.rx       rx_axis,
  axi4s_intf.tx       tx_axis,
  input logic[15:0]   div_count,
  input logic[15:0]   burst_count   // Note:  if div_count == burst_count bus will run at 100%
);


   logic [15:0]       div_counter;
   logic [15:0]       burst_counter;

   logic 	      bus_ready;
   
   assign tx_axis.tvalid =  rx_axis.tvalid & bus_ready;
   assign tx_axis.tdata  =  rx_axis.tdata;
   assign tx_axis.tkeep  =  rx_axis.tkeep;
   assign tx_axis.tlast  =  rx_axis.tlast;
   assign tx_axis.tid    =  rx_axis.tid;
   assign tx_axis.tdest  =  rx_axis.tdest;
   assign tx_axis.tuser  =  rx_axis.tuser;
   assign rx_axis.tready =  tx_axis.tready & bus_ready;

   always @(posedge rx_axis.aclk) begin
      if (!rx_axis.aresetn) begin
	 div_counter <= 1;
	 burst_counter <= 0;
	 bus_ready <= 1;
      end else begin
	 if ( div_counter == 1 ) begin
	    div_counter <= div_count;
	    burst_counter <= burst_count;
	 end else begin
	    div_counter <= div_counter - 1;
	    if (burst_counter != 0) burst_counter <= burst_counter - 1;
	 end

	 if (burst_counter == 0) begin
	    bus_ready <= 0;
	 end else begin
	    bus_ready <= 1;
	 end
      end 
   end // always @ (posedge rx_axis.aclk)

//   always @(posedge rx_axis.aclk) begin
//      if (div_count != 1) begin
//	 $display("div_counter = %d burst_counter = %d bus_ready = %b",div_counter,burst_counter,bus_ready);
//      end
//   end

endmodule // axi4s_shaper
