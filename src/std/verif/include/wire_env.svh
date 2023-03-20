class wire_env #(
    parameter type TRANSACTION_T = transaction,
    parameter type DRIVER_T=driver#(TRANSACTION_T),
    parameter type MONITOR_T=monitor#(TRANSACTION_T),
    parameter type SCOREBOARD_T=event_scoreboard#(TRANSACTION_T)
) extends component_env#(TRANSACTION_T, TRANSACTION_T, DRIVER_T, MONITOR_T, wire_model#(TRANSACTION_T), SCOREBOARD_T);

    local static const string __CLASS_NAME = "std_verif_pkg::wire_env";

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(string name="wire_env");
        // Create superclass instance
        super.new(name);

        // Create wire model component
        this.model = new();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

endclass
