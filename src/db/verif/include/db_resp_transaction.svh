class db_resp_transaction#(
    parameter type KEY_T = bit[15:0],
    parameter type VALUE_T = bit[31:0]
) extends std_verif_pkg::transaction;

    local static const string __CLASS_NAME = "db_verif_pkg::db_resp_transaction";

    //===================================
    // Properties
    //===================================
    const KEY_T key;
    const bit found;
    const VALUE_T value;
    const status_t status;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name="db_resp_transaction",
            input KEY_T key,
            input bit found=1'b0,
            input VALUE_T value='0,
            input status_t status=STATUS_OK
        );
        super.new(name);
        this.key = key;
        this.found = found;
        this.value = value;
        this.status = status;
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

    // Get string representation of transaction
    // [[ implements std_verif_pkg::transaction.to_string() ]]
    function string to_string();
        string str = $sformatf("Database response transaction: %s\n", get_name());
        str = {str, "------------------------------------------\n"};
        str = {str, $sformatf("KEY: 0x%x, FOUND: %x, VALUE: 0x%x\n", this.key, this.found, this.value)};
        str = {str, "------------------------------------------\n"};
        return str;
    endfunction

    // Compare transactions
    // [[ implements std_verif_pkg::transaction.compare() ]]
    function bit compare(input db_resp_transaction#(KEY_T, VALUE_T) t2, output string msg);
        if (this.key != t2.key) begin
            msg = $sformatf("KEY mismatch. A: 0x%x, B: 0x%x.", this.key, t2.key);
            return 0;
        end else if (this.status != t2.status) begin
            msg = $sformatf("STATUS mismatch. A: %x, B: %x.", this.status.name(), t2.status.name());
            return 0;
        end else if (this.found != t2.found) begin
            msg = $sformatf("FOUND mismatch. A: %x, B: %x.", this.found, t2.found);
            return 0;
        end else if (this.found && (this.value != t2.value)) begin
            msg = $sformatf("VALUE mismatch. A: %x, B: %x.", this.value, t2.value);
            return 0;
        end else begin
            msg = "Transactions match.";
            return 1;
        end
    endfunction
endclass
