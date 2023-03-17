// Base agent class for verification
// - interface class (not to be implemented directly)
// - describes interface for 'generic' agents, where methods are to be implemented by derived class
class agent extends component;

    local static const string __CLASS_NAME = "std_verif_pkg::agent";

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="agent");
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
    // Reset client
    virtual task reset_client(); endtask
    // Put all (driven) interfaces into idle state
    virtual task idle(); endtask
    // Wait for specified number of 'cycles', where the definition of 'cycle' is agent-specific
    virtual task _wait(input int cycles); endtask
    // Wait for client to be ready (after init/reset for example)
    virtual task wait_ready(); endtask

endclass : agent
