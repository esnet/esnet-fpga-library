// Reference predictor class for verification
// - abstract class (not to be implemented directly)
// - describes interface for model where each input transaction yields an
//   output transaction
virtual class predictor #(
    parameter type TRANSACTION_IN_T = transaction,
    parameter type TRANSACTION_OUT_T = TRANSACTION_IN_T
) extends model#(TRANSACTION_IN_T, TRANSACTION_OUT_T);

    local static const string __CLASS_NAME = "std_verif_pkg::predictor";

    //===================================
    // Pure Virtual Methods
    // (must be implemented by derived class)
    //===================================
    // Predict output transaction, given input transaction
    pure virtual function automatic TRANSACTION_OUT_T predict(input TRANSACTION_IN_T transaction);

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="predictor");
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
        TRANSACTION_OUT_T transaction_out;
        trace_msg("_process()");
        debug_msg(transaction.to_string());
        transaction_out = predict(transaction);
        _enqueue(transaction_out);
        debug_msg(transaction_out.to_string());
        trace_msg("_process() Done.");
    endtask

endclass : predictor
