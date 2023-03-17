class raw_model #(
    parameter type DATA_IN_T = byte,
    parameter type DATA_OUT_T = byte,
    parameter type T = model#(raw_transaction#(DATA_IN_T), raw_transaction#(DATA_OUT_T))
) extends T;

    local static const string __CLASS_NAME = "std_verif_pkg::raw_model";

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="raw_model");
        super.new(name);
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Reset model state
    // [[ implements std_verif_pkg::model._reset() ]]
    protected function automatic void _reset();
        trace_msg("_reset()");
        // Nothing to do
        trace_msg("_reset() Done.");
    endfunction

    // Process input transaction
    // [[ implements std_verif_pkg::model._process() ]]
    protected task _process(input TRANSACTION_IN_T transaction);
        trace_msg("_process()");
        _process_raw(transaction.data);
        trace_msg("_process() Done.");
    endtask

    // Enqueue transaction using raw data representation
    protected task _enqueue_raw(input DATA_OUT_T data_out);
        TRANSACTION_OUT_T transaction_out;
        trace_msg("_enqueue_raw()");
        transaction_out = new(.data(data_out));
        _enqueue(transaction_out);
        trace_msg("_enqueue_raw() Done.");
    endtask

    // Convert raw data to input transaction
    function automatic TRANSACTION_IN_T input_transaction_from_raw(input DATA_IN_T data_in);
        TRANSACTION_IN_T transaction_in = new(.data(data_in));
        return transaction_in;
    endfunction

    // Convert output transaction to raw data
    function automatic DATA_OUT_T output_transaction_to_raw(input TRANSACTION_OUT_T transaction_out);
        return transaction_out.data;
    endfunction

    //===================================
    // Virtual Methods
    // (to be implemented by derived classes)
    //===================================
    // Process (raw) input data transaction
    protected virtual task _process_raw(input DATA_IN_T data_in); endtask

endclass : raw_model
