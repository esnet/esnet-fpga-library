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

class wire_env #(
    parameter type TRANSACTION_T = transaction,
    parameter type DRIVER_T=driver#(TRANSACTION_T),
    parameter type MONITOR_T=monitor#(TRANSACTION_T),
    parameter type SCOREBOARD_T=event_scoreboard#(TRANSACTION_T)
) extends component_env#(TRANSACTION_T, TRANSACTION_T, DRIVER_T, MONITOR_T, wire_model#(TRANSACTION_T), SCOREBOARD_T);

    local static const string __CLASS_NAME = "std_verif_pkg::wire_env";

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(string name="wire_env");
        // Create superclass instance
        super.new(name);

        // Create wire model component
        this.model = new();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

endclass
