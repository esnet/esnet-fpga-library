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

// Base agent class for verification
// - interface class (not to be implemented directly)
// - describes interface for 'generic' agents, where methods are to be
//   implemented by derived class
class agent extends base;
    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="agent");
        super.new(name);
    endfunction

    //===================================
    // Virtual Methods
    // (to be implemented by derived class)
    //===================================
    // Reset agent state
    virtual function automatic void reset(); endfunction
    // Reset client
    virtual task reset_client(); endtask
    // Put all (driven) interfaces into idle state
    virtual task idle(); endtask
    // Wait for specified number of 'cycles', where the definition of 'cycle' is agent-specific
    virtual task _wait(input int cycles); endtask
    // Wait for client to be ready (after init/reset for example)
    virtual task wait_ready(); endtask

endclass : agent
