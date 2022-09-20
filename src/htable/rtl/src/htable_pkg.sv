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

package htable_pkg;

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef enum logic[7:0] {
        HTABLE_TYPE_UNSPECIFIED = 0,
        HTABLE_TYPE_SINGLE,
        HTABLE_TYPE_MULTI,
        HTABLE_TYPE_MULTI_STASH
    } htable_type_t;

    // Generic hash data type
    // - width is picked to accommodate any practical
    //   hash implementation, where hash is used to
    //   index into tables
    // - e.g. 32-bit hash supports hash table depths
    //        up to 4G entries
    typedef logic [31:0] hash_t;

    typedef enum {
        APP_WR_MODE_NONE,
        APP_WR_MODE_ROUND_ROBIN,
        APP_WR_MODE_BROADCAST
    } app_wr_mode_t;

endpackage : htable_pkg
