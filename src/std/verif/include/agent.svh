// Base agent class for verification
// - interface class (not to be implemented directly)
// - describes interface for 'generic' agents, where methods are to be implemented by derived class
virtual class agent extends component;

    local static const string __CLASS_NAME = "std_verif_pkg::agent";

    //===================================
    // Properties
    //===================================
    local semaphore __LOCK;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="agent");
        super.new(name);
        init_lock();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::agent.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    function automatic void init_lock();
        __LOCK = new(1);
    endfunction

    task lock();
        trace_msg("lock()");
        __LOCK.get();
        trace_msg("lock() Done.");
    endtask

    function automatic bit try_lock();
        bit lock_result;
        string lock_result_str;
        trace_msg("try_lock()");
        lock_result = __LOCK.try_get();
        lock_result_str = lock_result ? "successful" : "unsuccessful";
        trace_msg($sformatf("try_lock() Done. Lock %s.", lock_result_str));
        return lock_result;
    endfunction

    function automatic void unlock();
        trace_msg("unlock()");
        if (__LOCK.try_get()) error_msg("Unlock attempted but no lock set.");
        __LOCK.put();
        trace_msg("unlock() Done.");
    endfunction

    // Reset agent
    // [[ implements std_verif_pkg::component.reset() ]]
    function automatic void reset();
        trace_msg("reset()");
        _reset();
        init_lock();
        trace_msg("reset() Done.");
    endfunction

    //===================================
    // Virtual Methods
    // (to be implemented by derived class)
    //===================================
    // Reset agent
    protected virtual function automatic void _reset(); endfunction
    // Reset client
    virtual task reset_client(); endtask
    // Put all (driven) interfaces into idle state
    virtual task idle(); endtask
    // Wait for specified number of 'cycles', where the definition of 'cycle' is agent-specific
    virtual task _wait(input int cycles); endtask
    // Wait for client to be ready (after init/reset for example)
    virtual task wait_ready(); endtask

endclass : agent
