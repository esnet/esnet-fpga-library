class raw_scoreboard #(
    parameter type DATA_T = bit[15:0]
) extends event_scoreboard#(raw_transaction#(DATA_T));

    local static const string __CLASS_NAME = "std_verif_pkg::raw_scoreboard";

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(string name="raw_scoreboard");
        super.new(name);
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

endclass : raw_scoreboard
