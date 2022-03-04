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

// Scoreboard class for verification
// - represents base class for scoreboard
// - also represents generic implementation class (can be instantiated directly)
class scoreboard #(parameter type TRANSACTION_T = transaction) extends base;

    //===================================
    // Properties
    //===================================
    local int __got_cnt;
    local int __exp_cnt;

    mailbox #(TRANSACTION_T) got_inbox;
    mailbox #(TRANSACTION_T) exp_inbox;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="scoreboard");
        super.new(name);
    endfunction

    // Return number of received transactions processed
    function automatic int num_got_transactions();
        return __got_cnt;
    endfunction

    // Return number of expected transactions processed
    function automatic int num_exp_transactions();
        return __exp_cnt;
    endfunction

    // Reset scoreboard state
    // - base reset method; can be overloaded to provide application-specific behavour
    protected function automatic void _reset();
        // Nothing to do
    endfunction

    // - public 'wrapper' method with common accounting/reporting functions
    function automatic void reset();
        __got_cnt = 0;
        __exp_cnt = 0;
        _reset();
    endfunction

    // Process 'actual' received transaction
    // - base processing method; can be overloaded to provide application-specific behaviour
    protected function automatic void _process_got_transaction(input TRANSACTION_T transaction);
        info_msg($sformatf("Processed received transaction:\n%s", transaction.to_string()));
    endfunction
    // - public 'wrapper' method with common accounting/reporting functions
    function automatic void process_got_transaction(input TRANSACTION_T transaction);
        _process_got_transaction(transaction);
        __got_cnt++;
    endfunction

    // Process 'expected' received transaction
    // - base processing method; can be overloaded to provide application-specific behaviour
    protected function automatic void _process_exp_transaction(input TRANSACTION_T transaction);
        info_msg($sformatf("Processed expected transaction:\n%s", transaction.to_string()));
    endfunction
    // - public 'wrapper' method with common accounting/reporting functions
    function automatic void process_exp_transaction(input TRANSACTION_T transaction);
        _process_exp_transaction(transaction);
        __exp_cnt++;
    endfunction

endclass : scoreboard
