class state_resp#(parameter type STATE_T = bit) extends std_verif_pkg::transaction;

    local static const string __CLASS_NAME = "state_verif_pkg::state_resp";

    //===================================
    // Properties
    //===================================
    STATE_T state;

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

    // Copy from reference
    // [[ implements std_verif_pkg::transaction._copy() ]]
    virtual protected function automatic void _copy(input std_verif_pkg::transaction t2);
        state_resp#(STATE_T) resp;
        if (!$cast(resp, t2)) begin
            // Impossible to continue; raise fatal exception.
            $fatal(2, $sformatf("Type mismatch while copying '%s' to '%s'", t2.get_name(), this.get_name()));
        end
        this.state = resp.state;
    endfunction

    // Get string representation of transaction
    // [[ implements std_verif_pkg::transaction.to_string() ]]
    function automatic string to_string();
        string str;
        str = $sformatf("State update response '%s':\n", get_name());
        str = {str, $sformatf("\tSTATE: 0x%x\n", this.state)};
        return str;
    endfunction

    // Compare transaction against another
    // [[ implements std_verif_pkg::transaction.compare() ]]
    function automatic bit compare(input std_verif_pkg::transaction t2, output string msg);
        state_resp#(STATE_T) b;
        // Upcast generic transaction to raw transaction type
        if (!$cast(b, t2)) begin
            msg = $sformatf("Transaction type mismatch. Transaction '%s' is not of type %s or has unexpected parameterization.", t2.get_name(), __CLASS_NAME);
            return 0;
        end
        if (this.state !== b.state) begin
            msg = $sformatf(
                "Mismatch while comparing STATE values. A: 0x%0x, B: 0x%0x.",
                this.state,
                b.state
            );
            return 0;
        end
        msg = "State update responses match.";
        return 1;
    endfunction

endclass : state_resp
