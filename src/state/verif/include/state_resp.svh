class state_resp#(
    parameter type STATE_T = bit
) extends std_verif_pkg::transaction;

    local static const string __CLASS_NAME = "state_verif_pkg::state_resp";

    //===================================
    // Properties
    //===================================
    const STATE_T state;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name="state_resp",
            input STATE_T state
        );
        super.new(name);
        this.state = state;
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Get string representation of transaction
    // [[ implements to_string virtual method of std_verif_pkg::transaction ]]
    function automatic string to_string();
        string str;
        str = $sformatf("State update response '%s':\n", get_name());
        str = {str, $sformatf("\tSTATE: 0x%x\n", this.state)};
        return str;
    endfunction

    // Compare transaction against another
    // [[ implements compare virtual method of std_verif_pkg::transaction ]]
    function automatic bit compare(input state_resp#(STATE_T) t2, output string msg);
        if (this.state !== t2.state) begin
            msg = $sformatf(
                "Mismatch while comparing STATE values. A: 0x%0x, B: 0x%0x.",
                this.state,
                t2.state
            );
            return 0;
        end
        msg = "State update responses match.";
        return 1;
    endfunction

endclass : state_resp
