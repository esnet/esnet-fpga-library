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

package axi4s_pkg;

    // Typedefs
    typedef enum int {
        REG_SLICE_BYPASS,             // Connect input to output
        REG_SLICE_DEFAULT,            // Two-deep registered mode (supports back-to-back transfers), balances performance/fanout
        REG_SLICE_LIGHTWEIGHT,        // Inserts one 'bubble' cycle after each transfer
        REG_SLICE_FULLY_REGISTERED,   // Similar to DEFAULT, except all payload/handshake outputs are driven directly from registers
        REG_SLICE_SLR_CROSSING,       // Adds extra pipeline stages to optimally cross one SLR boundary (all SLR crossings are flop-to-flop with fanout=1)
//      REG_SLICE_SLR_TDM_CROSSING,   // Not supported (requires 2x clock) [Similar to SLR crossing, except consumes half number of payload wires across boundary; requires 2x clock)
//      REG_SLICE_MULTI_SLR_CROSSING, // Supports spanning zero or more SLR boundaries using a single slice instance; also inserts additional pipeline stages within each SLR to help meet timing goals.
        REG_SLICE_AUTO_PIPELINED,     // ??
        REG_SLICE_PRESERVE_SI,        // ??
        REG_SLICE_PRESERVE_MI         // ??
    } xilinx_reg_slice_config_t;

   
    typedef enum logic {
        STANDARD,
        IGNORES_TREADY
    } axi4s_mode_t;

    typedef enum int {
        USER,
        BUFFER_CONTEXT,
        PKT_ERROR
    } axi4s_tuser_mode_t;

    typedef enum int {
        GOOD,
        OVFL,
        ERRORS
    } axi4s_probe_mode_t;

    typedef enum int {
        PULL,
        PUSH
    } axi4s_pipe_mode_t;

    typedef enum int {
        SOP,
        HDR_TLAST
    } axi4s_sync_mode_t;

    typedef struct packed {
        logic [15:0] wr_ptr;
        logic        hdr_tlast;
    } tuser_buffer_context_mode_t;

    typedef enum int {
        FULL,
        LITE
    } axi4s_ila_mode_t;

endpackage : axi4s_pkg
