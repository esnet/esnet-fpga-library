virtual class raw_predictor #(
    parameter type DATA_IN_T = byte,
    parameter type DATA_OUT_T = byte
) extends raw_model#(
    DATA_IN_T,
    DATA_OUT_T,
    predictor#(raw_transaction#(DATA_IN_T), raw_transaction#(DATA_OUT_T))
);

    local static const string __CLASS_NAME = "std_verif_pkg::raw_predictor";

    //===================================
    // Pure Virtual Methods
    // (must be implemented by derived class)
    //===================================
    // Process (raw) input data transaction
    pure virtual function DATA_OUT_T predict_raw(input DATA_IN_T data_in);

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="raw_predictor");
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

    // Predict output transaction, given input transaction
    // [[ implements std_verif_pkg::predictor.predict() ]]
    function automatic raw_transaction#(DATA_OUT_T) predict(input raw_transaction#(DATA_IN_T) transaction);
        DATA_OUT_T data_out;
        raw_transaction#(DATA_OUT_T) transaction_out;
        trace_msg("predict()");
        data_out = predict_raw(transaction.data);
        transaction_out = new(.data(data_out));
        trace_msg("predict() Done.");
        return transaction_out;
    endfunction

    // Process (raw) input transaction
    // [[ implements std_verif_pkg::raw_model._process_raw() ]]
    protected task _process_raw(input DATA_IN_T data_in);
        DATA_OUT_T data_out;
        trace_msg("_process_raw()");
        data_out = predict_raw(data_in);
        _enqueue_raw(data_out);
        trace_msg(" _process_raw() Done.");
    endtask

endclass : raw_predictor
