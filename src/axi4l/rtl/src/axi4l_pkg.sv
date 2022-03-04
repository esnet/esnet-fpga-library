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

    // Xilinx-specific
    typedef enum int {
        REG_SLICE_BYPASS,             // Connect input to output
        REG_SLICE_FULL,               // One latency cycle, no bubble cycles
        REG_SLICE_FORWARD,
        REG_SLICE_REVERSE,
        REG_SLICE_INPUTS,
        REG_SLICE_LIGHT,              // Inserts one 'bubble' cycle after each transfer
        REG_SLICE_SLR_CROSSING,       // Three latency cycles, no bubble cycles
//      REG_SLICE_SLR_TDM_CROSSING,   // Not supported (requires 2x clock)
//      REG_SLICE_MULTI_SLR_CROSSING, // Supports spanning zero or more SLR boundaries using a single slice instance
        REG_SLICE_SI_MI_REG           // SI Reg for AW/W/AR channels, MI Reg for B/R channels
    } xilinx_reg_slice_config_t;

endpackage : axi4l_pkg
