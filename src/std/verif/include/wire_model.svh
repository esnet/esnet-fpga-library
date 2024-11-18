class wire_model #(
    parameter type TRANSACTION_T = transaction
) extends model#(TRANSACTION_T, TRANSACTION_T);

    local static const string __CLASS_NAME = "std_verif_pkg::wire_model";

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(string name="wire_model");
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

    // Process input transaction
    // [[ implements std_verif_pkg::model._process() ]]
    protected task _process(input TRANSACTION_IN_T transaction);
        // Send input transaction as output transaction
        _enqueue(transaction);
    endtask

endclass : wire_model
