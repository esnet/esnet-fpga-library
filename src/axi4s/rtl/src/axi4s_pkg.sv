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
   
    typedef enum logic {
        STANDARD,
        IGNORES_TREADY
    } axi4s_mode_t;

    typedef enum int {
        USER,
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
        logic [15:0] pid;
        logic        hdr_tlast;
    } tuser_split_join_t;

    typedef enum int {
        FULL,
        LITE
    } axi4s_ila_mode_t;

endpackage : axi4s_pkg
