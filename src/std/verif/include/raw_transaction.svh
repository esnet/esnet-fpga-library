// Raw transaction class
// - type is expected to be bit vector or packed struct
class raw_transaction#(parameter type DATA_T = bit) extends transaction;

    local static const string __CLASS_NAME = "std_verif_pkg::raw_transaction";

    //===================================
    // Properties
    //===================================
    DATA_T data;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name="raw_transaction",
            input DATA_T data
        );
        super.new(name);
        this.data = data;
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
        raw_transaction#(DATA_T) raw_trans;
        if (!$cast(raw_trans, t2)) begin
            // Impossible to continue; raise fatal exception.
            $fatal(2, $sformatf("Type mismatch while copying '%s' to '%s'", t2.get_name(), this.get_name()));
        end
        this.data = raw_trans.data;
    endfunction

    // Get string representation of transaction
    // [[ implements to_string virtual method of std_verif_pkg::transaction ]]
    function automatic string to_string();
        string str;
        str = $sformatf("Raw transaction '%s': 0x%0x\n", get_name(), this.data);
        return str;
    endfunction

    // Compare transaction against another
    // [[ implements compare virtual method of std_verif_pkg::transaction ]]
    virtual function automatic bit compare(input transaction t2, output string msg);
        raw_transaction#(DATA_T) b;
        // Upcast generic transaction to raw transaction type
        if (!$cast(b, t2)) begin
            msg = $sformatf("Transaction type mismatch. Transaction '%s' is not of type %s or has unexpected parameterization.", t2.get_name(), __CLASS_NAME);
            return 0;
        end
        // Compare transactions
        if (this.data === b.data) begin
            msg = "Raw transactions match.";
            return 1;
        end else begin
            msg = $sformatf("Raw data mismatch. A: 0x%0x, B: 0x%0x", this.data, b.data);
            return 0;
        end
    endfunction

endclass : raw_transaction
