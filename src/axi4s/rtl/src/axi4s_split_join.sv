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
   parameter logic BIGENDIAN = 0  // Little endian by default.
) (
   axi4s_intf.rx     axi4s_in,
   axi4s_intf.tx     axi4s_out,
   axi4s_intf.tx     axi4s_hdr_out,
   axi4s_intf.rx     axi4s_hdr_in,

   input logic [15:0] hdr_length  // specified in bytes.
);

   localparam int  DATA_BYTE_WID = axi4s_hdr_out.DATA_BYTE_WID;
   localparam type TID_T         = axi4s_hdr_out.TID_T;
   localparam type TDEST_T       = axi4s_hdr_out.TDEST_T;

   axi4s_intf #( .TUSER_MODE(BUFFER_CONTEXT), .DATA_BYTE_WID(DATA_BYTE_WID), 
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(tuser_buffer_context_mode_t) ) axi4s_to_buffer   ();

   axi4s_intf #( .TUSER_MODE(BUFFER_CONTEXT), .DATA_BYTE_WID(DATA_BYTE_WID), 
                 .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(tuser_buffer_context_mode_t) ) axi4s_from_buffer ();


   // header splitter instantiation
   axi4s_split #(
      .BIGENDIAN (BIGENDIAN)
   ) axi4s_split_0 (
      .axi4s_in      (axi4s_in),
      .axi4s_out     (axi4s_to_buffer),
      .axi4s_hdr_out (axi4s_hdr_out),
      .hdr_length    (hdr_length)
   );


   // instantiate and terminate unused AXI-L interfaces.
   axi4l_intf axil_to_probe ();
   axi4l_intf axil_to_ovfl  ();
   axi4l_intf axil_to_fifo  ();

   axi4l_intf_controller_term axi4l_to_probe_term (.axi4l_if (axil_to_probe));
   axi4l_intf_controller_term axi4l_to_ovfl_term  (.axi4l_if (axil_to_ovfl));
   axi4l_intf_controller_term axi4l_to_fifo_term  (.axi4l_if (axil_to_fifo));

   // packet fifo instantiation
   axi4s_pkt_fifo_sync #(
       .FIFO_DEPTH(256)
    ) fifo_0 (
       .axi4s_in       (axi4s_to_buffer),
       .axi4s_out      (axi4s_from_buffer),
       .axil_to_probe  (axil_to_probe),
       .axil_to_ovfl   (axil_to_ovfl),
       .axil_if        (axil_to_fifo)
    );

   
   // payload joiner instantiation
   axi4s_join #(
      .BIGENDIAN (BIGENDIAN)
   ) axi4s_join_0 (
      .axi4s_hdr_in  (axi4s_hdr_in),
      .axi4s_in      (axi4s_from_buffer),
      .axi4s_out     (axi4s_out)
   );

endmodule // axi4s_split_join
