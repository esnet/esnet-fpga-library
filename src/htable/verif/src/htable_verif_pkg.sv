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

package htable_verif_pkg;

    import htable_reg_verif_pkg::*;

    // Verif class definitions
    // (declared here to enforce htable_verif_pkg:: namespace for verification definitions)
    `include "htable_cuckoo_reg_agent.svh"
    `include "htable_fast_update_reg_agent.svh"

    //===================================
    // Typedefs
    //===================================
    typedef struct {
        bit [63:0] insert_ok;
        bit [63:0] insert_fail;
        bit [63:0] delete_ok;
        bit [63:0] delete_fail;
        bit [31:0] active;
    } stats_t;

endpackage : htable_verif_pkg
