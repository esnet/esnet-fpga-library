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

// Reference model class for verification
// - interface class (not to be implemented directly)
// - describes interface for 'generic' reference models, where methods are to be
//   implemented by extended class
class model #(
    parameter type TRANSACTION_IN_T = transaction,
    parameter type TRANSACTION_OUT_T = transaction
) extends base;
    //===================================
    // Properties
    //===================================
    local int __cnt;

    mailbox #(TRANSACTION_IN_T)  inbox;
    mailbox #(TRANSACTION_OUT_T) outbox;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="model");
        super.new(name);
    endfunction

    // Return number of transactions processed
    function automatic int num_transactions();
        return __cnt;
    endfunction

    function automatic void reset();
        __cnt = 0;
        _reset();
    endfunction

    function automatic TRANSACTION_OUT_T apply(input TRANSACTION_IN_T transaction_in);
        __cnt++;
        return _apply(transaction_in);
    endfunction

    //===================================
    // Virtual Methods
    //===================================
    protected virtual function automatic void _reset(); endfunction
    protected virtual function automatic TRANSACTION_OUT_T _apply(input TRANSACTION_IN_T transaction_in); endfunction
 
endclass : model
