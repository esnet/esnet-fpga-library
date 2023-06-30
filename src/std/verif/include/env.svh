// Base environment class for verification
// - abstract class (not to be implemented directly)
// - describes interface for 'generic' environments, where methods are to be
//   implemented by derived class
class env extends component;

    local static const string __CLASS_NAME = "std_verif_pkg::env";

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

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Set reset timeout
    function automatic void set_reset_timeout(input int TIMEOUT);
        this.__RESET_TIMEOUT = TIMEOUT;
    endfunction

    // Apply reset pulse to DUT and wait for reset done
    task reset_dut();
        trace_msg("reset_dut()");
        debug_msg("Applying DUT reset...");
        reset_vif.pulse(8);
        wait_ready();
        debug_msg("Done. DUT reset completed successfully.");
        trace_msg("reset_dut() Done.");
    endtask

    // Assert DUT reset
    task assert_dut_reset();
        trace_msg("assert_dut_reset()");
        reset_vif.assert_sync();
        trace_msg("assert_dut_reset() Done.");
    endtask

    // Deassert DUT reset
    task deassert_dut_reset();
        automatic bit timeout;
        trace_msg("deassert_dut_reset()");
        reset_vif.deassert_sync();
        reset_vif.wait_ready(timeout, this.__RESET_TIMEOUT);
        if (timeout) error_msg("TIMEOUT. deassert_dut_reset() not complete.");
        else         trace_msg("deassert_dut_reset() Done.");
    endtask

    // Wait for reset/initialization to complete
    virtual task wait_ready();
        automatic bit timeout;
        trace_msg("wait_ready()");
        reset_vif.wait_ready(timeout, this.__RESET_TIMEOUT);
        if (timeout) error_msg("TIMEOUT. wait_ready() not complete.");
        else         debug_msg("wait_ready() Done.");
    endtask

    // Put all (driven) interfaces into quiescent state
    virtual task idle(); endtask

endclass : env
