// Base environment class for verification
// - abstract class (can't be instantiated directly)
// - describes interface for 'generic' environments, where methods are to be implemented by derived class
virtual class env extends component;

    local static const string __CLASS_NAME = "std_verif_pkg::env";

    //===================================
    // Pure Virtual Methods
    // (must be implemented by derived class)
    //===================================
    pure virtual task assert_dut_reset();
    pure virtual task deassert_dut_reset();
    pure virtual task wait_dut_ready();

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="env");
        super.new(name);
        _reset();
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        super.destroy();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Reset environment
    // [[ implements std_verif_pkg::component._reset() ]]
    virtual protected function automatic void _reset();
        // Nothing to do typically
    endfunction

    // Quiesce all interfaces
    // [[ implements std_verif_pkg::component._idle() ]]
    virtual protected task _idle();
        // Nothing to do typically
    endtask

    // Reset DUT and block until ready
    virtual task reset_dut();
        trace_msg("reset_dut()");
        debug_msg("Applying DUT reset...");
        assert_dut_reset();
        deassert_dut_reset();
        wait_dut_ready();
        debug_msg("Done. DUT reset completed successfully.");
        trace_msg("reset_dut() Done.");
    endtask

    // Initialize environment
    // [[ implements std_verif_pkg::component._init() ]]
    virtual protected task _init();
        trace_msg("_init()");
        reset_dut();
        trace_msg("_init() Done.");
    endtask

    // Start environment execution (run loop)
    virtual protected task _run();
        trace_msg("_run()");
        info_msg("Starting environment...");
        trace_msg("_run() Done.");
    endtask

    // [[ overrides std_verif_pkg::component.run ]]
    virtual task run();
        idle();
        reset();
        init();
        super.run();
    endtask


endclass : env
