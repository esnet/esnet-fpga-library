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

package state_pkg;

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef enum logic[7:0] {
        STATE_TYPE_UNSPECIFIED = 0,
        STATE_TYPE_VALID,
        STATE_TYPE_READ,
        STATE_TYPE_WRITE,
        STATE_TYPE_FLAGS,
        STATE_TYPE_COUNTER,
        STATE_TYPE_COUNT,
        STATE_TYPE_HISTOGRAM,
        STATE_TYPE_TIMER,
        STATE_TYPE_AGING,
        STATE_TYPE_CACHE
    } state_type_t;

    typedef enum {
        RETURN_MODE_PREV_STATE, // Returns previous state
        RETURN_MODE_NEW_STATE,  // Returns new (updated) state
        RETURN_MODE_DELTA       // Returns difference between new and previous state
    } return_mode_t;

    // -----------------------------
    // Functions
    // -----------------------------
    virtual class State#(type ID_T);
        static function int numIDs();
            return 2**$bits(ID_T);
        endfunction
    endclass

endpackage : state_pkg
