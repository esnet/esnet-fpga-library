class db_req_transaction #(
    parameter type KEY_T = bit[15:0],
    parameter type VALUE_T = bit[31:0]
) extends std_verif_pkg::transaction;

    local static const string __CLASS_NAME = "db_verif_pkg::db_req_transaction";

    //===================================
    // Properties
    //===================================
    const KEY_T key;
    const command_t command;
    const VALUE_T value;

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

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
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
    function bit compare(input db_req_transaction#(KEY_T, VALUE_T) t2, output string msg);
        if (this.key !== t2.key) begin
            msg = $sformatf("KEY mismatch: A: 0x%x, B: 0x%x.", this.key, t2.key);
            return 0;
        end else if (this.command !== t2.command) begin
            msg = $sformatf("COMMAND mismatch: A: %s, B: %s.", this.command.name(), t2.command.name());
            return 0;
        end else if (this.value !== t2.value) begin
            msg = $sformatf("VALUE mismatch: A: 0x%0x, B: 0x%0x.", this.value, t2.value);
            return 0;
        end else begin
            msg = "Transactions match.";
            return 1;
        end
    endfunction
endclass
