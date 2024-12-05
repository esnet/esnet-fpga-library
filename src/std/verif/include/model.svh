// Reference model class for verification
// - abstract class (can't be instantiated directly)
// - describes interface for 'generic' reference models, where methods are to be implemented by extended class
virtual class model #(
    parameter type TRANSACTION_IN_T = transaction,
    parameter type TRANSACTION_OUT_T = TRANSACTION_IN_T
) extends component;

    local static const string __CLASS_NAME = "std_verif_pkg::model";

    //===================================
    // Properties
    //===================================
    local int __cnt_in = 0;
    local int __cnt_out = 0;

    mailbox #(TRANSACTION_IN_T)  inbox;
    mailbox #(TRANSACTION_OUT_T) outbox;

    //===================================
    // Pure Virtual Methods
    // (to be implemented by derived class)
    //===================================
    pure virtual protected task _process(input TRANSACTION_IN_T transaction); // Process transaction

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="model");
        super.new(name);
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        inbox = null;
        outbox = null;
        super.destroy();
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

    // Build component
    // [[ implements std_verif_pkg::component._build() ]]
    virtual function automatic void _build();
        // Nothing to do typically
    endfunction

    // Flush remaining transactions from inbox
    local function automatic void __flush_input();
        TRANSACTION_IN_T transaction;
        if (inbox != null) while (inbox.try_get(transaction));
    endfunction

    // Reset model state
    // [[ implements std_verif_pkg::component._reset() ]]
    virtual protected function automatic void _reset();
        __cnt_in = 0;
        __cnt_out = 0;
    endfunction

    // Quiesce all interfaces
    // [[ implements std_verif_pkg::component._idle() ]]
    virtual protected task _idle();
        // Nothing to do typically
    endtask

    // Dequeue next input transaction for processing
    protected task _dequeue(output TRANSACTION_IN_T transaction);
        trace_msg("_dequeue()");
        debug_msg(
            $sformatf("Waiting to dequeue input transaction #%0d.", __cnt_in+1)
        );
        inbox.get(transaction);
        __cnt_in++;
        trace_msg("_dequeue() Done.");
    endtask

    // Enqueue output transaction
    protected task _enqueue(input TRANSACTION_OUT_T transaction);
        trace_msg("_enqueue()");
        debug_msg(
            $sformatf("Enqueueing output transaction #%0d.", __cnt_out+1)
        );
        outbox.put(transaction);
        __cnt_out++;
        trace_msg("_enqueue() Done.");
    endtask

    // Initialize model for processing
    // [[ implements std_verif_pkg::component._init() ]]
    virtual protected task _init();
        // Reset state
        reset();
        // Flush input queue
        __flush_input();
    endtask

    // Model process - receive transactions from inbox and process
    // [[ implements std_verif_pkg::component._run() ]]
    virtual protected task _run();
        trace_msg("_run()");
        info_msg("Running...");
        forever begin
            TRANSACTION_IN_T transaction;
            _dequeue(transaction);
            _process(transaction);
        end
        trace_msg("_run() Done.");
    endtask

endclass : model
