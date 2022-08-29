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

package axi4l_pkg;

    // Typedefs
    typedef enum logic [1:0] {
        RESP_OKAY = 2'b00,
        RESP_EXOKAY = 2'b01,
        RESP_SLVERR = 2'b10,
        RESP_DECERR = 2'b11
    } resp_encoding_t;

    typedef union packed {
        resp_encoding_t encoded;
        bit [1:0]       raw;
    } resp_t;


    typedef enum {
        AXI4L_BUS_WIDTH_32,
        AXI4L_BUS_WIDTH_64
    } axi4l_bus_width_t;

    // Functions
    function automatic int get_axi4l_bus_width_in_bytes(input axi4l_bus_width_t bus_width);
        case (bus_width)
            AXI4L_BUS_WIDTH_32 : return 4;
            AXI4L_BUS_WIDTH_64 : return 8;
            default : return 4;
        endcase
    endfunction

endpackage : axi4l_pkg
