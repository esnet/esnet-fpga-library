class db_scoreboard #(
    parameter type KEY_T = logic[15:0],
    parameter type VALUE_T = logic[31:0]
) extends std_verif_pkg::event_scoreboard#(db_resp_transaction#(KEY_T, VALUE_T));

    local static const string __CLASS_NAME = "db_verif_pkg::db_scoreboard";

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(string name="db_scoreboard");
        super.new(name);
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

endclass : db_scoreboard
