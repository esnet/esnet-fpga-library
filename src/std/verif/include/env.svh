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

// Base environment class for verification
// - interface class (not to be implemented directly)
// - describes interface for 'generic' environments, where methods are to be
//   implemented by derived class
class env extends base;
    
    //===================================
    // Properties
    //===================================
    // Reset interface
    virtual std_reset_intf reset_vif;

    local int __RESET_TIMEOUT = 0;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="env");
        super.new(name);
    endfunction

    // Set reset timeout
    function automatic void set_reset_timeout(input int TIMEOUT);
        this.__RESET_TIMEOUT = TIMEOUT;
    endfunction

    // Apply reset pulse to DUT and wait for reset done
    task reset_dut();
        automatic bit timeout;
        debug_msg("--- env.reset_dut() ---");
        reset_vif.pulse(8);
        reset_vif.wait_ready(timeout, this.__RESET_TIMEOUT);
        if (timeout) error_msg("TIMEOUT. env.reset_dut() not complete.");
        else         debug_msg("--- env.reset_dut() Done. ---");
    endtask

    // Assert DUT reset
    task assert_dut_reset();
        debug_msg("--- env.assert_dut_reset() ---");
        reset_vif.assert_sync();
        debug_msg("--- env.assert_dut_reset() Done. ---");
    endtask

    // Deassert DUT reset
    task deassert_dut_reset();
        automatic bit timeout;
        debug_msg("--- env.deassert_dut_reset() ---");
        reset_vif.deassert_sync();
        reset_vif.wait_ready(timeout, this.__RESET_TIMEOUT);
        if (timeout) error_msg("TIMEOUT. env.deassert_dut_reset() not complete.");
        else         debug_msg("--- env.deassert_dut_reset() Done. ---");
    endtask

    // Wait for reset/initialization to complete
    task wait_ready();
        automatic bit no_timeout;
        debug_msg("--- env.wait_ready() ---");
        reset_vif.wait_ready(no_timeout, 0);
        debug_msg("--- env.wait_ready() Done. ---");
    endtask

    //===================================
    // Virtual Methods
    // (to be implemented by derived class)
    //===================================
    // Connect environment
    virtual function automatic void connect(); endfunction
    // Reset environment state
    virtual function automatic void reset(); endfunction
    // Put all (driven) interfaces into quiescent state
    virtual task idle(); endtask

endclass :env
