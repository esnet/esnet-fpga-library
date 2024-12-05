class db_req_transaction #(
    parameter type KEY_T = bit[15:0],
    parameter type VALUE_T = bit[31:0]
) extends std_verif_pkg::transaction;

    local static const string __CLASS_NAME = "db_verif_pkg::db_req_transaction";

    //===================================
    // Properties
    //===================================
    KEY_T key;
    command_t command;
    VALUE_T value;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name="db_req_transaction",
            input command_t command,
            input KEY_T key='0,
            input VALUE_T value='0
        );
        super.new(name);
        this.key = key;
        this.command = command;
        this.value = value;
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
        db_req_transaction#(KEY_T, VALUE_T) trans;
        if (!$cast(trans, t2)) begin
            // Impossible to continue; raise fatal exception.
            $fatal(2, $sformatf("Type mismatch while copying '%s' to '%s'", t2.get_name(), this.get_name()));
        end
        this.key = trans.key;
        this.command = trans.command;
        this.value = trans.value;
    endfunction

    // Get string representation of transaction
    // [[ implements std_verif_pkg::transaction.to_string() ]]
    function string to_string();
        string str = $sformatf("Database request transaction: %s\n", get_name());
        str = {str, "------------------------------------------\n"};
        str = {str, $sformatf("COMMAND: %s", this.command.name())};
        str = {str, $sformatf("KEY: 0x%x", this.key)};
        str = {str, $sformatf("VALUE: 0x%x", this.value)};
        str = {str, "------------------------------------------\n"};
        return str;
    endfunction

    // Compare transactions
    // [[ implements std_verif_pkg::transaction.compare() ]]
    function automatic bit compare(input std_verif_pkg::transaction t2, output string msg);
        db_req_transaction#(KEY_T, VALUE_T) b;
        // Upcast generic transaction to raw transaction type
        if (!$cast(b, t2)) begin
            msg = $sformatf("Transaction type mismatch. Transaction '%s' is not of type %s or has unexpected parameterization.", t2.get_name(), __CLASS_NAME);
            return 0;
        end
        // Compare transactions
        if (this.key !== b.key) begin
            msg = $sformatf("KEY mismatch: A: 0x%x, B: 0x%x.", this.key, b.key);
            return 0;
        end else if (this.command !== b.command) begin
            msg = $sformatf("COMMAND mismatch: A: %s, B: %s.", this.command.name(), b.command.name());
            return 0;
        end else if (this.value !== b.value) begin
            msg = $sformatf("VALUE mismatch: A: 0x%0x, B: 0x%0x.", this.value, b.value);
            return 0;
        end else begin
            msg = "Transactions match.";
            return 1;
        end
    endfunction
endclass
