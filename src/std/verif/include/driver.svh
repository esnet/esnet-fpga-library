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

// Base driver class for verification
// - interface class (not to be implemented directly)
// - describes interface for 'generic' driver, where methods are to be
//   implemented by derived class
class driver #(
    parameter type TRANSACTION_T = transaction
) extends base;
    //===================================
    // Properties
    //===================================
    local int __cnt;

    mailbox #(TRANSACTION_T) inbox;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="driver");
        super.new(name);
    endfunction
 
    // Return number of transactions sent
    function automatic int num_transactions();
        return __cnt;
    endfunction

    // Reset driver state
    function automatic void reset();
        __cnt = 0;
        _reset();
    endfunction

    // Send transaction
    task send(input TRANSACTION_T transaction);
        _send(transaction);
        __cnt++;
    endtask

    //===================================
    // Virtual Methods
    // (to be implemented by derived class)
    //===================================
    // Reset driver state
    virtual function automatic void _reset(); endfunction
    // Put (driven) interface in idle state
    virtual task idle(); endtask
    // Wait for specified number of 'cycles' on the driven interface
    virtual task _wait(input int cycles); endtask
    // Wait for interface to be ready to accept transactions (after reset/init, for example)
    virtual task wait_ready(); endtask
    // Send transaction
    virtual task _send(input TRANSACTION_T transaction); endtask

endclass : driver
