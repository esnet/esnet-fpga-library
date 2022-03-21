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

package db_pkg;

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef enum logic[7:0] {
        TYPE_UNSPECIFIED = 0,
        TYPE_CACHE       = 1,
        TYPE_STATE       = 2,
        TYPE_STATS       = 3
    } type_t;

    typedef logic[7:0] subtype_t;

    typedef enum logic [2:0] {
        COMMAND_NOP,
        COMMAND_GET,
        COMMAND_SET,
        COMMAND_UNSET,
        COMMAND_REPLACE,
        COMMAND_CLEAR
    } command_t;

    typedef enum logic [1:0] {
        STATUS_UNSPECIFIED,
        STATUS_OK,
        STATUS_ERROR,
        STATUS_TIMEOUT
    } status_t;

endpackage : db_pkg

