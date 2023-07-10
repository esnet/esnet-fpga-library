// Base component class for verification
// - abstract class (not to be implemented directly)
// - describes interface for 'generic' components, where methods are to be
//   implemented by sublass
virtual class component extends base;

    local static const string __CLASS_NAME = "std_verif_pkg::component";

    //===================================
    // Properties
    //===================================
    local event __stop;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="component");
        super.new(name);
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Start component execution (run loop)
    task start();
        trace_msg("start()");
        fork
            begin
                fork
                    begin
                        _start();
                        trace_msg("_start done");
                    end
                    begin
                        wait(__stop.triggered);
                        trace_msg("Stop event received...");
                    end
                join_any
                disable fork;
            end
        join_none;
        trace_msg("start() Done.");
    endtask

    // Stop component execution
    task stop();
        trace_msg("stop()");
        -> __stop;
        trace_msg("stop() Done.");
    endtask

    //===================================
    // Virtual Methods
    // (to be implemented by derived class)
    //===================================
    // Connect component (interfaces, etc.)
    virtual function automatic void connect(); endfunction
    // Reset component state
    virtual function automatic void reset(); endfunction
    // Start component execution
    protected virtual task _start(); endtask

endclass
