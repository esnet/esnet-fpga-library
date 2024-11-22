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

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        agent = null;
        super.destroy();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Build environment
    // [[ implements std_verif_pkg::env._build() ]]
    protected virtual function automatic void _build();
        trace_msg("_build()");
        register_subcomponent(agent);
        super._build();
        trace_msg("_build() Done.");
    endfunction

endclass
