// Reference model class for verification
// - interface class (not to be implemented directly)
// - describes interface for 'generic' reference models, where methods are to be
//   implemented by extended class
class model #(
    parameter type TRANSACTION_IN_T = transaction,
    parameter type TRANSACTION_OUT_T = TRANSACTION_IN_T
) extends component;

    local static const string __CLASS_NAME = "std_verif_pkg::model";

    //===================================
    // Properties
    //===================================
    local int __cnt_in;
    local int __cnt_out;

    mailbox #(TRANSACTION_IN_T)  inbox;
    mailbox #(TRANSACTION_OUT_T) outbox;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="model");
        super.new(name);
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Return number of transactions processed
    function automatic int num_input_transactions();
        return __cnt_in;
    endfunction

    function automatic int num_output_transactions();
        return __cnt_out;
    endfunction

    local function automatic void __flush_input();
        TRANSACTION_IN_T transaction;
        if (inbox != null) while (inbox.try_get(transaction));
    endfunction

    // Reset model state
    // [[ implements std_verif_pkg::component.reset() ]]
    function automatic void reset();
        trace_msg("reset()");

        // Perform derived class reset
        _reset();

        // Flush input queue
        __flush_input();

        // Reset counts
        __cnt_in = 0;
        __cnt_out = 0;
        trace_msg("reset() Done.");
    endfunction

    // Dequeue next input transaction for processing
    task _dequeue(output TRANSACTION_IN_T transaction);
        trace_msg("_dequeue()");
        debug_msg(
            $sformatf("Waiting to dequeue input transaction #%0d.", __cnt_in+1)
        );
        inbox.get(transaction);
        __cnt_in++;
        trace_msg("_dequeue() Done.");
    endtask

    // Enqueue output transaction
    task _enqueue(input TRANSACTION_OUT_T transaction);
        trace_msg("_enqueue()");
        debug_msg(
            $sformatf("Enqueueing output transaction #%0d.", __cnt_out+1)
        );
        outbox.put(transaction);
        __cnt_out++;
        trace_msg("_enqueue() Done.");
    endtask

    // Model process - receive transactions from inbox and process
    // [[ implements std_verif_pkg::component._start() ]]
    task start();
        trace_msg("start()");
        info_msg("Running...");
        forever begin
            TRANSACTION_IN_T transaction;
            _dequeue(transaction);
            _process(transaction);
        end
        trace_msg("start() Done.");
    endtask

    //===================================
    // Virtual Methods
    //===================================
    // Reset model state
    protected virtual function automatic void _reset(); endfunction
    // Process transaction
    protected virtual task _process(input TRANSACTION_IN_T transaction); endtask

endclass : model
