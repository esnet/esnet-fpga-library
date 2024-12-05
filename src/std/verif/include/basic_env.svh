// Basic environment, including reset interface only
class basic_env#(parameter bit RESET_ACTIVE_LOW = 1'b0) extends env;

    local static const string __CLASS_NAME = "std_verif_pkg::basic_env";

    //===================================
    // Properties
    //===================================
    // Reset interface
    virtual std_reset_intf#(.ACTIVE_LOW(RESET_ACTIVE_LOW)) reset_vif;

    local int __RESET_TIMEOUT = 0;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="basic_env");
        super.new(name);
        // WORKAROUND-INIT-PROPS {
        //     Provide/repeat default assignments for all remaining instance properties here.
        //     Works around an apparent object initialization bug (as of Vivado 2024.2)
        //     where properties are not properly allocated when they are not assigned
        //     in the constructor.
        this.__RESET_TIMEOUT = 0;
        this.reset_vif = null;
        // } WORKAROUND-INIT-PROPS
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        reset_vif = null;
        super.destroy();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Build environment (instantiate subcomponents, connect interfaces, etc.)
    // [[ implements std_verif_pkg::env._build() ]]
    protected virtual function automatic void _build();
        // Nothing to do
    endfunction
    // Set reset timeout (in reset interface clock cycles)
    function automatic void set_reset_timeout(input int TIMEOUT);
        __RESET_TIMEOUT = TIMEOUT;
    endfunction

    // Get reset timeout (in reset interface clock cycles)
    function automatic int get_reset_timeout();
        return __RESET_TIMEOUT;
    endfunction

    // Block until DUT is ready (reset completed)
    // [[ implements std_verif_pkg::env.wait_dut_ready() ]]
    virtual task wait_dut_ready();
        automatic bit timeout;
        trace_msg("wait_ready()");
        reset_vif.wait_ready(timeout, get_reset_timeout());
        if (timeout) error_msg("TIMEOUT. wait_ready() not complete.");
        else         debug_msg("wait_ready() Done.");
    endtask

    // Assert DUT reset
    // [[ implements std_verif_pkg::env.assert_dut_reset() ]]
    virtual task assert_dut_reset();
        trace_msg("assert_dut_reset()");
        reset_vif.assert_sync();
        reset_vif._wait(8);
        trace_msg("assert_dut_reset() Done.");
    endtask

    // Deassert DUT reset
    // [[ implements std_verif_pkg::env.deassert_dut_reset() ]]
    virtual task deassert_dut_reset();
        automatic bit timeout;
        trace_msg("deassert_dut_reset()");
        reset_vif.deassert_sync();
        reset_vif._wait(8);
        trace_msg("deassert_dut_reset() Done.");
    endtask

    // Wait for specified number of 'cycles'
    task wait_n(input int cycles);
        reset_vif._wait(cycles);
    endtask

endclass : basic_env
