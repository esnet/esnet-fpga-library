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

// -----------------------------------------------------------------------------
// axi4s_pkt_discard is used to discard the full ingress packet when an axi4s 
// data transaction fails due fifo overflow.  
// This component should be used on any axi4s interface that ignores the tready 
// flow control signal.
// axi4s_pkt_discard is a synchronous component which employs a memory sized to
// buffer up to 3 max packets.
// -----------------------------------------------------------------------------

module axi4s_pkt_discard
   import mem_pkg::*;
#(
   parameter int MAX_PKT_LEN = 9100,  // max number of bytes per packet.
   parameter int DATA_WID    = 582    // tdata(512b)+tkeep(64b)+tdest(2b)+tid(2b)+tlast(1b)+tuser(1b).
)  (
   axi4s_intf.rx   axi4s_in_if,
   axi4s_intf.tx   axi4s_out_if
);
   localparam int MAX_PKT_WRDS = $ceil(MAX_PKT_LEN/64.0);
   localparam int FIFO_DEPTH   = MAX_PKT_WRDS * 3;  // depth supports 3 max pkts.
   localparam int ADDR_WID     = $clog2(FIFO_DEPTH);

   // pipeline stages match mem_ram_sdp_sync pipelining.
   localparam xilinx_ram_style_t _RAM_STYLE = get_default_ram_style(2**ADDR_WID, DATA_WID, 1);
   localparam int WR_PIPELINE_STAGES = get_default_wr_pipeline_stages(_RAM_STYLE);
   localparam int RD_PIPELINE_STAGES = get_default_rd_pipeline_stages(_RAM_STYLE);


   // fifo write and read context signals
   logic [ADDR_WID:0] wr_ptr, wr_ptr_nxt;
   logic [ADDR_WID:0] wr_ptr_p;

   logic [ADDR_WID:0] rd_ptr;
   logic              rd_req_p [RD_PIPELINE_STAGES+1]; // one additional stage for memory latency.

   logic [ADDR_WID:0] fill_level;
   logic              almost_full;
   logic              empty;

   // pkt discard signals
   logic [ADDR_WID:0] sop_ptr;
   logic              ovfl;
   logic              discard;
   logic              tx_pending;

   // internal axi4s signals
   logic              axi4s_in_rst;
   logic              axi4s_in_val;
   logic              axi4s_out_rst;

   assign axi4s_in_rst  = ~axi4s_in_if.aresetn;
   assign axi4s_in_val  =  axi4s_in_if.tready && axi4s_in_if.tvalid;
   assign axi4s_out_rst = ~axi4s_out_if.aresetn;


   mem_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_WID)) mem_wr_if (.clk(axi4s_in_if.aclk));
   mem_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_WID)) mem_rd_if (.clk(axi4s_out_if.aclk));

   assign axi4s_in_if.tready = mem_wr_if.rdy && !discard && !ovfl;


   // ---- write context logic ----
   assign wr_ptr_nxt = wr_ptr + 1;

   always @(posedge axi4s_in_if.aclk)
      if (axi4s_in_rst) wr_ptr <= '0;
      else begin
	 // if discarding a packet, restore sop pointer when tlast is asserted.
	 // otherwise increment pointer for each valid transfer.
         if (discard && axi4s_in_if.tvalid && axi4s_in_if.tlast) wr_ptr <= sop_ptr;
         else if (axi4s_in_val)                                  wr_ptr <= wr_ptr_nxt;
      end

   generate
      if (WR_PIPELINE_STAGES > 0) begin : g__wr_ptr_pipe
         logic [ADDR_WID:0] __wr_ptr_p [WR_PIPELINE_STAGES]; // ptr pipelined as per mem_ram_sdp_sync.
	 
         always @(posedge axi4s_in_if.aclk)
            if (axi4s_in_rst) __wr_ptr_p <= '{WR_PIPELINE_STAGES{'0}};
            else begin
               __wr_ptr_p[0] <= wr_ptr;
               for (int i = 1; i < WR_PIPELINE_STAGES; i++) __wr_ptr_p[i] <= __wr_ptr_p[i-1];
            end

         assign wr_ptr_p = __wr_ptr_p[WR_PIPELINE_STAGES-1];
      end : g__wr_ptr_pipe

      else if (WR_PIPELINE_STAGES == 0) begin : g__no_wr_ptr_pipe 
         assign wr_ptr_p = wr_ptr;
      end : g__no_wr_ptr_pipe

  endgenerate

   // assert almost_full when there is only FIFO space for one more ingress packet.
   assign fill_level  = wr_ptr-rd_ptr;
   assign almost_full = fill_level > (FIFO_DEPTH-MAX_PKT_WRDS);

   // assert fifo_overflow if almost_full is asserted when new packet arrives i.e. tvalid && sop.
   assign ovfl = almost_full && axi4s_in_if.tvalid && axi4s_in_if.sop;

   always @(posedge axi4s_in_if.aclk)
      if (axi4s_in_rst) begin
         sop_ptr <= 0;
         discard <= 0;
      end else begin
         if (axi4s_in_val && axi4s_in_if.tlast) sop_ptr <= wr_ptr_nxt; // save last sop pointer.

         // if discard is asserted, deassert discard at the end of the inbound packet.
	 // else assert discard signal when fifo overflow occurs.
         if (discard && axi4s_in_if.tvalid && axi4s_in_if.tlast) discard <= 1'b0;
         else if (ovfl) discard <= 1'b1;
      end


   // ---- memory instantiation and signalling ----
   assign mem_wr_if.rst  = axi4s_in_rst;
   assign mem_wr_if.en   = 1'b1;
   assign mem_wr_if.req  = axi4s_in_val;
   assign mem_wr_if.addr = wr_ptr[ADDR_WID-1:0];
   assign mem_wr_if.data = { axi4s_in_if.tuser,
                             axi4s_in_if.tlast,
                             axi4s_in_if.tid,
                             axi4s_in_if.tdest,
                             axi4s_in_if.tkeep,
                             axi4s_in_if.tdata } ;
   mem_ram_sdp_sync #(
      .ADDR_WID  ( ADDR_WID ),
      .DATA_WID  ( DATA_WID ),
      .RESET_FSM ( 0 )
   ) mem_ram_sdp_sync_0 (
      .clk       ( axi4s_in_if.aclk ),
      .srst      ( axi4s_in_rst ),
      .mem_wr_if ( mem_wr_if ),
      .mem_rd_if ( mem_rd_if )
   );

   assign mem_rd_if.rst  = axi4s_out_rst;
   assign mem_rd_if.en   = 1'b1;
   assign mem_rd_if.req  = axi4s_out_if.tready && !empty && !tx_pending;
   assign mem_rd_if.addr = rd_ptr[ADDR_WID-1:0];


   // ---- write context logic ----
   always @(posedge axi4s_out_if.aclk)
      if (axi4s_out_rst) begin
         rd_ptr   <= 0;
         rd_req_p <= '{RD_PIPELINE_STAGES+1{'0}};
      end else begin
         if (mem_rd_if.req) rd_ptr <= rd_ptr + 1;

         rd_req_p[0] <= mem_rd_if.req;
         for (int i = 1; i < RD_PIPELINE_STAGES+1; i++) rd_req_p[i] <= rd_req_p[i-1];
      end

   // assert tx_pending if rd_ptr reaches sop_ptr.
   // defers transfer until sop is overwritten on tlast, and the full packet is buffered.
   assign tx_pending = (rd_ptr == sop_ptr);

   // assert empty when pipelined wr_ptr equals rd_ptr.
   assign empty = (rd_ptr == wr_ptr_p);


   // axis4s output signalling.
   assign axi4s_out_if.aclk    = axi4s_in_if.aclk;
   assign axi4s_out_if.aresetn = axi4s_in_if.aresetn;
   assign axi4s_out_if.tvalid  = rd_req_p[RD_PIPELINE_STAGES];  // connect tvalid to output of rd pipeline.
   assign axi4s_out_if.tdata   = mem_rd_if.data[511:0];
   assign axi4s_out_if.tkeep   = mem_rd_if.data[575:512];
   assign axi4s_out_if.tdest   = mem_rd_if.data[577:576];
   assign axi4s_out_if.tid     = mem_rd_if.data[579:578];
   assign axi4s_out_if.tlast   = mem_rd_if.data[580];
   assign axi4s_out_if.tuser   = mem_rd_if.data[581];

endmodule
