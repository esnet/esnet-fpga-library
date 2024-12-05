// Base agent class for verification
// - abstract class (can't to be implemented directly)
// - describes interface for 'generic' agents, where methods are to be implemented by derived class
virtual class agent extends component;

    local static const string __CLASS_NAME = "std_verif_pkg::agent";

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="agent");
        super.new(name);
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        super.destroy();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::agent.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Build component
    // [[ implements std_verif_pkg::component._build() ]]
    virtual protected function automatic void _build();
        // Nothing to do typically
    endfunction

    // Reset agent state
    // [[ implements std_verif_pkg::component._reset() ]]
    virtual protected function automatic void _reset();
        // Nothing to do typically
    endfunction

    // Quiesce all interfaces
    virtual protected task _idle();
        // Nothing to do typically
    endtask

    // Perform any necessary initialization, etc. and block until agent is ready for processing
    // [[ implements std_verif_pkg::component._init() ]]
    virtual protected task _init();
        // Nothing to do typically
    endtask

    // Agent process
    // [[ implements std_verif_pkg::component._run() ]]
    virtual protected task _run();
        // Nothing to do typically
    endtask

endclass : agent
