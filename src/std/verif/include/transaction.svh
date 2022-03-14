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

// Base transaction class for verification
// - interface class (not to be implemented directly)
// - describes interface for 'generic' transactions, where methods are to be
//   implemented by sublass
class transaction extends base;

    local static const string __CLASS_NAME = "std_verif_pkg::transaction";

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="transaction");
        super.new(name);
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    //===================================
    // Virtual Methods
    // (to be implemented by derived class)
    //===================================
    // String representation
    virtual function automatic string to_string(); endfunction
    // Compare transaction
    virtual function automatic bit compare(input transaction t2, output string msg); endfunction

endclass
