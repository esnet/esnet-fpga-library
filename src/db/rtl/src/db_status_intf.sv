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

interface db_status_intf;

    // Imports
    import db_pkg::*;

    // Signals
    // -- Peripheral to controller
    type_t     _type;
    subtype_t  subtype;
    logic [31:0] size;
    logic [31:0] fill;

    modport controller(
        input  _type,
        input  subtype,
        input  size,
        input  fill
    );

    modport peripheral(
        output _type,
        output subtype,
        output size,
        output fill
    );
endinterface : db_status_intf

// Database status controller termination helper module
module db_status_intf_controller_term (
    db_status_intf.controller status_if
);
    // Tie off controller outputs
    // (None)

endmodule : db_status_intf_controller_term

// Database status peripheral termination helper module
module db_status_intf_peripheral_term (
    db_status_intf.peripheral status_if
);
    // Tie off peripheral outputs
    assign status_if._type = db_pkg::DB_TYPE_UNSPECIFIED;
    assign status_if.sub_type = 0;
    assign status_if.size = 0;
    assign status_if.fill = 0;

endmodule : db_status_intf_peripheral_term

