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

module axi4s_ila
   import axi4s_pkg::*;
#(
   parameter axi4s_ila_mode_t MODE = FULL,
   parameter int PIPE_STAGES = 1
) (
   axi4s_intf.prb axis_in
);

  (* mark_debug="true" *)  logic [511:0]  tdata  [PIPE_STAGES+1];
  (* mark_debug="true" *)  logic          tvalid [PIPE_STAGES+1];
  (* mark_debug="true" *)  logic          tlast  [PIPE_STAGES+1];
  (* mark_debug="true" *)  logic [63:0]   tkeep  [PIPE_STAGES+1];
  (* mark_debug="true" *)  logic          tready [PIPE_STAGES+1];
  (* mark_debug="true" *)  logic [31:0]   tuser  [PIPE_STAGES+1];

  assign tdata  [PIPE_STAGES] = axis_in.tdata;
  assign tvalid [PIPE_STAGES] = axis_in.tvalid;
  assign tlast  [PIPE_STAGES] = axis_in.tlast;
  assign tkeep  [PIPE_STAGES] = axis_in.tkeep;
  assign tready [PIPE_STAGES] = axis_in.tready;
  assign tuser  [PIPE_STAGES] = {'0, axis_in.tuser};

  generate
     if (PIPE_STAGES > 0) 
       for (genvar i = 0; i < PIPE_STAGES; i++)
         always_ff @(posedge axis_in.aclk) begin
           tdata[i]  <= tdata[i+1];
           tvalid[i] <= tvalid[i+1];
           tlast[i]  <= tlast[i+1];
           tkeep[i]  <= tkeep[i+1];
           tready[i] <= tready[i+1];
           tuser[i]  <= tuser[i+1];
         end
  endgenerate

  generate
      if (MODE == FULL) begin : g__full
         ila_axi4s ila_axi4s_0 (
            .clk(axis_in.aclk),
            .probe0(tdata[0]),
            .probe1(tvalid[0]),
            .probe2(tlast[0]),
            .probe3(tkeep[0]),
            .probe4(tready[0]),
            .probe5(tuser[0]));
      end : g__full

      else if (MODE == LITE) begin : g__lite
         ila_axi4s_lite ila_axi4s_lite_0 (
            .clk(axis_in.aclk),
            .probe0(tdata[0][7:0]),
            .probe1(tvalid[0]),
            .probe2(tlast[0]),
            .probe3(tkeep[0][0]),
            .probe4(tready[0]),
            .probe5(tuser[0][0]));
      end : g__lite
   endgenerate

endmodule // axi4s_ila
