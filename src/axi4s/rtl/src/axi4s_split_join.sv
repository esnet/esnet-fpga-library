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
// axi4s_split_join is a module that combines the axi4s split, join and
// pkt_buffer components for the purpose of separating the headers of a packet
// stream (for in-line header processing).  It also recombines the processed pkt 
// header stream with the packet payloads (after processing).  
// -----------------------------------------------------------------------------

module axi4s_split_join
   import axi4s_pkg::*;
#(
   parameter logic BIGENDIAN    = 0,  // Little endian by default.
   parameter logic IN_PIPE      = 1,
   parameter logic OUT_PIPE     = 1,
   parameter logic HDR_IN_PIPE  = 1,
   parameter logic HDR_OUT_PIPE = 1
 ) (
   axi4s_intf.rx     axi4s_in,
   axi4s_intf.tx     axi4s_out,
   axi4s_intf.tx     axi4s_hdr_out,
   axi4s_intf.rx     axi4s_hdr_in,

   axi4l_intf.peripheral axil_if,

   input logic [15:0] hdr_length  // specified in bytes.
);

   logic  enable;

   localparam int  DATA_BYTE_WID = axi4s_hdr_out.DATA_BYTE_WID;
   localparam type TID_T         = axi4s_hdr_out.TID_T;
   localparam type TDEST_T       = axi4s_hdr_out.TDEST_T;

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T) ) axi4s_in_p ();

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T) ) __axi4s_in_p ();

   axi4s_intf #( .DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T) ) axi4s_out_p ();

   axi4s_intf #( .TUSER_MODE(BUFFER_CONTEXT), .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(tuser_buffer_context_mode_t) ) axi4s_hdr_in_p ();

   axi4s_intf #( .TUSER_MODE(BUFFER_CONTEXT), .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(tuser_buffer_context_mode_t) ) __axi4s_hdr_in_p ();

   axi4s_intf #( .TUSER_MODE(BUFFER_CONTEXT), .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(tuser_buffer_context_mode_t) ) axi4s_hdr_out_p ();

   axi4s_intf #( .MODE(IGNORES_TREADY), .TUSER_MODE(BUFFER_CONTEXT), .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(tuser_buffer_context_mode_t) ) axi4s_to_buffer ();

   axi4s_intf #( .TUSER_MODE(BUFFER_CONTEXT), .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(tuser_buffer_context_mode_t) ) axi4s_to_buffer_p ();

   axi4s_intf #( .TUSER_MODE(BUFFER_CONTEXT), .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(tuser_buffer_context_mode_t) ) axi4s_from_buffer ();

   axi4s_intf #( .TUSER_MODE(BUFFER_CONTEXT), .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(tuser_buffer_context_mode_t) ) axi4s_from_buffer_p ();

   axi4s_intf #( .TUSER_MODE(BUFFER_CONTEXT), .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(tuser_buffer_context_mode_t) ) axi4s_to_split_mux ();

   axi4s_intf #( .TUSER_MODE(BUFFER_CONTEXT), .DATA_BYTE_WID(DATA_BYTE_WID),
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(tuser_buffer_context_mode_t) ) axi4s_to_join_mux ();

   generate
      if (IN_PIPE)
         axi4s_full_pipe
            #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(tuser_buffer_context_mode_t))
            in_pipe_0 (.axi4s_if_from_tx(axi4s_in), .axi4s_if_to_rx(axi4s_in_p));
      else
         axi4s_intf_connector in_intf_connector_0  (.axi4s_from_tx(axi4s_in), .axi4s_to_rx(axi4s_in_p));

      if (OUT_PIPE)
         axi4s_full_pipe
            #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(tuser_buffer_context_mode_t))
            out_pipe_0 (.axi4s_if_from_tx(axi4s_out_p), .axi4s_if_to_rx(axi4s_out));
      else
         axi4s_intf_connector out_intf_connector_0 (.axi4s_from_tx(axi4s_out_p), .axi4s_to_rx(axi4s_out));

      if (HDR_IN_PIPE)
         axi4s_full_pipe
            #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(tuser_buffer_context_mode_t))
            hdr_in_pipe_0 (.axi4s_if_from_tx(axi4s_hdr_in), .axi4s_if_to_rx(axi4s_hdr_in_p));
      else
         axi4s_intf_connector hdr_in_intf_connector_0  (.axi4s_from_tx(axi4s_hdr_in), .axi4s_to_rx(axi4s_hdr_in_p));

      if (HDR_OUT_PIPE)
         axi4s_full_pipe
            #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(tuser_buffer_context_mode_t))
            hdr_out_pipe_0 (.axi4s_if_from_tx(axi4s_hdr_out_p), .axi4s_if_to_rx(axi4s_hdr_out));
      else
         axi4s_intf_connector hdr_out_intf_connector_0 (.axi4s_from_tx(axi4s_hdr_out_p), .axi4s_to_rx(axi4s_hdr_out));

   endgenerate

   assign enable = hdr_length != 0;  // disable joiner if hdr_length is zero.



   // header splitter instantiation
   axi4s_split #(
      .BIGENDIAN (BIGENDIAN)
   ) axi4s_split_0 (
      .axi4s_in      (__axi4s_in_p),
      .axi4s_out     (axi4s_to_buffer_p),
      .axi4s_hdr_out (axi4s_to_split_mux),
      .hdr_length    (hdr_length),
      .enable        (enable)
   );

   // mux instantation used to bypass axi4s_join if not enabled.
   axi4s_intf_bypass_mux #(
      .PIPE_STAGES(1), .DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(tuser_buffer_context_mode_t)
    ) bypass_split_mux (
      .axi4s_in         (axi4s_in_p),
      .axi4s_to_block   (__axi4s_in_p),
      .axi4s_from_block (axi4s_to_split_mux),
      .axi4s_out        (axi4s_hdr_out_p),
      .bypass           (!enable)
    );

   axi4s_full_pipe
      #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(tuser_buffer_context_mode_t))
      to_buffer_pipe_0 (.axi4s_if_from_tx(axi4s_to_buffer_p), .axi4s_if_to_rx(axi4s_to_buffer));




   // instantiate and terminate unused AXI-L interfaces.
   axi4l_intf axil_to_probe ();
   axi4l_intf axil_to_ovfl  ();
   axi4l_intf axil_to_fifo  ();

   axi4s_split_join_decoder axi4s_split_join_decoder_0 (
      .axil_if (axil_if),
      .probe_to_buffer_axil_if (axil_to_probe),
      .drops_to_buffer_axil_if (axil_to_ovfl),
      .pkt_fifo_axil_if (axil_to_fifo)
   );

   // packet fifo instantiation
   axi4s_pkt_fifo_sync #(
       .FIFO_DEPTH(512),
       .STR_FWD_MODE(0) // FIFO needs to store-and-forward, but achieves this when axi4s_to_buffer i/f IGNORES_TREADY.
    ) fifo_0 (
       .srst           (!enable),
       .axi4s_in       (axi4s_to_buffer),
       .axi4s_out      (axi4s_from_buffer),
       .axil_to_probe  (axil_to_probe),
       .axil_to_ovfl   (axil_to_ovfl),
       .axil_if        (axil_to_fifo)
    );

   axi4s_ila axi4s_ila_to_buffer   (.axis_in(axi4s_to_buffer));
   axi4s_ila axi4s_ila_from_buffer (.axis_in(axi4s_from_buffer));

   axi4s_full_pipe
      #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(tuser_buffer_context_mode_t))
      from_buffer_pipe_0 (.axi4s_if_from_tx(axi4s_from_buffer), .axi4s_if_to_rx(axi4s_from_buffer_p));

   // payload joiner instantiation
   axi4s_join #(
      .BIGENDIAN (BIGENDIAN)
   ) axi4s_join_0 (
      .axi4s_hdr_in  (__axi4s_hdr_in_p),
      .axi4s_in      (axi4s_from_buffer_p),
      .axi4s_out     (axi4s_to_join_mux),
      .enable        (enable)
   );

   // mux instantation used to bypass axi4s_join if not enabled.
   axi4s_intf_bypass_mux #(
      .PIPE_STAGES(1), .DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(tuser_buffer_context_mode_t)
    ) bypass_join_mux (
      .axi4s_in         (axi4s_hdr_in_p),
      .axi4s_to_block   (__axi4s_hdr_in_p),
      .axi4s_from_block (axi4s_to_join_mux),
      .axi4s_out        (axi4s_out_p),
      .bypass           (!enable)
    );

endmodule // axi4s_split_join
