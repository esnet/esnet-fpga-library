// Base environment class for 'controlled' component verification, where the component
// is characterized as having input/output 'data' interfaces (attached to
// driver/monitor, respectively), and a 'control' interface (attached to an agent).
class component_ctrl_env #(
    parameter type TRANSACTION_IN_T = transaction,
    parameter type TRANSACTION_OUT_T = transaction,
    parameter type DRIVER_T=driver#(TRANSACTION_IN_T),
    parameter type MONITOR_T=monitor#(TRANSACTION_OUT_T),
    parameter type MODEL_T=model#(TRANSACTION_IN_T,TRANSACTION_OUT_T),
    parameter type SCOREBOARD_T=scoreboard#(TRANSACTION_OUT_T),
    parameter type AGENT_T = agent
) extends component_env#(TRANSACTION_IN_T, TRANSACTION_OUT_T, DRIVER_T, MONITOR_T, MODEL_T, SCOREBOARD_T);
    
    local static const string __CLASS_NAME = "std_verif_pkg::component_ctrl_env";

    //===================================
    // Properties
    //===================================
    AGENT_T   agent;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="component_ctrl_env");
        super.new(name);
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Set debug level (verbosity)
    // [[ overrides std_verif_pkg::base.set_debug_level() ]]
    function automatic void set_debug_level(input int DEBUG_LEVEL);
        super.set_debug_level(DEBUG_LEVEL);
        agent.set_debug_level(DEBUG_LEVEL);
    endfunction

    // Reset environment
    // [[ overrides component_env.reset() ]]
    virtual function automatic void reset();
        trace_msg("reset()");
        super.reset();
        agent.reset();
        trace_msg("reset() Done.");
    endfunction

    // Put all (driven) interfaces into quiescent state
    // [[ overrides component_env.idle() ]]
    virtual task idle();
        trace_msg("idle()");
        fork
            super.idle();
            agent.idle();
        join
        trace_msg("idle() Done.");
    endtask

    // Wait for environment to be ready for transactions (after init/reset for example)
    // [[ overrides component_env.wait_ready() method ]]
    virtual task wait_ready();
        trace_msg("wait_ready()");
        fork
            super.wait_ready();
            agent.wait_ready();
        join
        trace_msg("wait_ready() Done.");
    endtask

endclass
