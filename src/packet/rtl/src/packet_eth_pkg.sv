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

package packet_eth_pkg;

    //===================================
    // Parameters
    //===================================
    localparam int ADDR_WID = 48;
    localparam int ETHERTYPE_WID = 16;

    //===================================
    // Typedefs
    //===================================
    typedef logic [ADDR_WID-1:0]      addr_t;
    typedef logic [ETHERTYPE_WID-1:0] ethertype_t;

    // MAC header specification
    typedef struct packed {
        addr_t dst_addr;      // Destination MAC address
        addr_t src_addr;      // Source MAC address
        ethertype_t eth_type; // EtherType
    } hdr_t;

    //===================================
    // Derived Parameters
    //===================================
    localparam int HDR_BYTES = $bits(hdr_t) / 8;

endpackage : packet_eth_pkg
