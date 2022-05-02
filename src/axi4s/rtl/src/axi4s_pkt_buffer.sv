// =============================================================================
//  NOTICE: This computer software was prepared by The Regents of the
//  University of California through Lawrence Berkeley National Laboratory
//  and Peter Bengough hereinafter the Contractor, under Contract No.
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
// axi4s_pkt_buffer is 
// -----------------------------------------------------------------------------

module axi4s_pkt_buffer
   import axi4s_pkg::*;
   import mem_pkg::*;
#(
   parameter int ADDR_WID = 10  // DEPTH = 2^^ADDR_WID = 2^^10 = 1024
)  (
   axi4s_intf.rx             axi4s_in,
   axi4s_intf.tx             axi4s_out,

   input logic               rd_req,
   input logic [ADDR_WID:0]  rd_ptr,   // ptr is 1 bit larger than addr for ovfl detection.
   input logic [ADDR_WID:0]  wr_ptr,

   output logic [ADDR_WID:0] wr_ptr_p  // pipelined wr_ptr.
);

   localparam int  DATA_BYTE_WID = axi4s_in.DATA_BYTE_WID;
   localparam type TID_T         = axi4s_in.TID_T;
   localparam type TDEST_T       = axi4s_in.TDEST_T;
   localparam type TUSER_T       = axi4s_in.TUSER_T;

   typedef struct packed {
       logic                          tlast;
       TID_T                          tid;
       TDEST_T                        tdest;
       TUSER_T                        tuser;
       logic [DATA_BYTE_WID-1:0]      tkeep;
       logic [DATA_BYTE_WID-1:0][7:0] tdata;
   } mem_data_t;

   mem_data_t   wr_data, rd_data;

   localparam int DEPTH = 2**ADDR_WID;
   localparam int DATA_WID = $size(wr_data);

   // match pipeline stages to mem_ram_sdp_sync_0 pipelining.
   localparam xilinx_ram_style_t RAM_STYLE = mem_ram_sdp_sync_0.i_mem_sdp_sync_core.__RAM_STYLE;
   localparam int WR_PIPELINE_STAGES       = mem_ram_sdp_sync_0.i_mem_sdp_sync_core.WR_PIPELINE_STAGES;
   localparam int RD_PIPELINE_STAGES       = mem_ram_sdp_sync_0.i_mem_sdp_sync_core.RD_PIPELINE_STAGES;

   logic rd_req_p [RD_PIPELINE_STAGES+1]; // pipelined rd_req.  one additional stage for memory latency.


   mem_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_WID)) mem_wr_if (.clk(axi4s_in.aclk));
   mem_intf #(.ADDR_WID(ADDR_WID), .DATA_WID(DATA_WID)) mem_rd_if (.clk(axi4s_in.aclk));


   assign axi4s_in.tready =  mem_wr_if.rdy;


   // ---- write ptr pipeline logic ----
   generate
      if (WR_PIPELINE_STAGES > 0) begin : g__wr_ptr_pipe
         logic [ADDR_WID:0] __wr_ptr_p [WR_PIPELINE_STAGES]; // ptr pipelined as per mem_ram_sdp_sync.
	 
         always @(posedge axi4s_in.aclk)
            if (!axi4s_in.aresetn) __wr_ptr_p <= '{WR_PIPELINE_STAGES{'0}};
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



   // ---- memory instantiation and signalling ----
   assign wr_data.tlast = axi4s_in.tlast;
   assign wr_data.tid   = axi4s_in.tid;
   assign wr_data.tdest = axi4s_in.tdest;
   assign wr_data.tuser = axi4s_in.tuser;
   assign wr_data.tkeep = axi4s_in.tkeep;
   assign wr_data.tdata = axi4s_in.tdata;

   assign mem_wr_if.rst  = ~axi4s_in.aresetn;
   assign mem_wr_if.en   = 1'b1;
   assign mem_wr_if.req  = axi4s_in.tready && axi4s_in.tvalid;
   assign mem_wr_if.addr = wr_ptr[ADDR_WID-1:0];
   assign mem_wr_if.data = wr_data;

   mem_ram_sdp_sync #(
      .ADDR_WID  ( ADDR_WID ),
      .DATA_WID  ( DATA_WID ),
      .RESET_FSM ( 1 )
   ) mem_ram_sdp_sync_0 (
      .clk       ( axi4s_in.aclk ),
      .srst      ( ~axi4s_in.aresetn ),
      .mem_wr_if ( mem_wr_if ),
      .mem_rd_if ( mem_rd_if )
   );

   assign mem_rd_if.rst  = ~axi4s_in.aresetn;
   assign mem_rd_if.en   = 1'b1;
   assign mem_rd_if.req  = rd_req;
   assign mem_rd_if.addr = rd_ptr[ADDR_WID-1:0];

   assign rd_data = mem_rd_if.data;



   // ---- read request pipeline logic ----
   always @(posedge axi4s_in.aclk)
      if (!axi4s_in.aresetn) begin
         rd_req_p <= '{RD_PIPELINE_STAGES+1{'0}};
      end else begin
         rd_req_p[0] <= mem_rd_if.req;
         for (int i = 1; i < RD_PIPELINE_STAGES+1; i++) rd_req_p[i] <= rd_req_p[i-1];
      end

   
   // axis4s output signalling.
   assign axi4s_out.aclk    = axi4s_in.aclk;
   assign axi4s_out.aresetn = axi4s_in.aresetn;
   assign axi4s_out.tvalid  = rd_req_p[RD_PIPELINE_STAGES];  // connect tvalid to output of rd pipeline.
   assign axi4s_out.tlast   = rd_data.tlast;
   assign axi4s_out.tid     = rd_data.tid;
   assign axi4s_out.tdest   = rd_data.tdest;
   assign axi4s_out.tuser   = rd_data.tuser;
   assign axi4s_out.tkeep   = rd_data.tkeep;
   assign axi4s_out.tdata   = rd_data.tdata;

endmodule
