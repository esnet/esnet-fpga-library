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

package apb_pkg;

    // ------------------------
    // Typedefs
    // ------------------------
    // PPROT
    typedef struct packed {
        logic instruction_data_n;
        logic secure;
        logic privileged;
    } pprot_encoding_t;

    typedef union packed {
        pprot_encoding_t encoded;
        logic [2:0]      raw;
    } pprot_t;

    localparam pprot_encoding_t PPROT_ENCODING_DEFAULT = '{privileged: 1'b0, secure: 1'b0, instruction_data_n: 1'b0};
    localparam pprot_t PPROT_DEFAULT = PPROT_ENCODING_DEFAULT;

endpackage : apb_pkg
