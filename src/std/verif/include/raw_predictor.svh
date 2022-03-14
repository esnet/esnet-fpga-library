// =============================================================================
//  NOTICE: This computer software was prepared by The Regents of the
//  University of California through Lawrence Berkeley National Laboratory
//  and Jonathan Sewter hereinafter the Contractor, under Contract No.
//  DE-AC02-05CH11231 with the Department of Energy (DOE). All rights in the
//  computer software are reserved by DOE on behalf of the United States
//  Government and the Contractor as provided in the Contract. You are
//  authorized to use this computer software for Governmental purposes but it
//  is not to be released or distributed to the public.
//
//  NEITHER THE GOVERNMENT NOR THE CONTRACTOR MAKES ANY WARRANTY, EXPRESS OR
//  IMPLIED, OR ASSUMES ANY LIABILITY FOR THE USE OF THIS SOFTWARE.
//
//  This notice including this sentence must appear on any copies of this
//  computer software.
// =============================================================================

class raw_predictor #(
    parameter type DATA_IN_T = byte,
    parameter type DATA_OUT_T = byte
) extends raw_model#(
    DATA_IN_T,
    DATA_OUT_T,
    predictor#(raw_transaction#(DATA_IN_T), raw_transaction#(DATA_OUT_T))
);

    local static const string __CLASS_NAME = "std_verif_pkg::raw_predictor";

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="raw_predictor");
        super.new(name);
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

    //===================================
    // Virtual Methods
    // (to be implemented by derived classes)
    //===================================
    // Process (raw) input data transaction
    virtual function DATA_OUT_T predict_raw(input DATA_IN_T data_in); endfunction

endclass : raw_predictor
