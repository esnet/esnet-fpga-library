virtual class raw_model #(
    parameter type DATA_IN_T = byte,
    parameter type DATA_OUT_T = byte
) extends model#(raw_transaction#(DATA_IN_T), raw_transaction#(DATA_OUT_T));

    local static const string __CLASS_NAME = "std_verif_pkg::raw_model";

    //===================================
    // Pure Virtual Methods
    // (must be implemented by derived class)
    //===================================
    // Process (raw) input data transaction
    pure virtual protected task _process_raw(input DATA_IN_T data_in);

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="raw_model");
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
        trace_msg("_process()");
        _process_raw(raw_transaction#(DATA_IN_T)::to_raw(transaction));
        trace_msg("_process() Done.");
    endtask

    // Enqueue transaction using raw data representation
    protected task _enqueue_raw(input DATA_OUT_T data_out);
        TRANSACTION_OUT_T transaction_out;
        trace_msg("_enqueue_raw()");
        transaction_out = raw_transaction#(DATA_OUT_T)::from_raw(data_out);
        _enqueue(transaction_out);
        trace_msg("_enqueue_raw() Done.");
    endtask

endclass : raw_model
