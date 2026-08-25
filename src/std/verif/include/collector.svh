// Collector class for verification
// - abstract class (can't be instantiated directly)
// - assembles individual transactions into complete, high-level sequences
// - N:1 mapping: N transactions in, one sequence out via outbox
// - correlation and completion logic are protocol-specific; implement in _process()
virtual class collector #(
    parameter type TRANSACTION_T = transaction,
    parameter type SEQUENCE_T    = TRANSACTION_T
) extends component;

    local static const string __CLASS_NAME = "std_verif_pkg::collector";

    //===================================
    // Properties
    //===================================
    local int __cnt_in = 0;
    local int __cnt_out = 0;

    mailbox #(TRANSACTION_T) inbox;
    mailbox #(SEQUENCE_T)    outbox;

    //===================================
    // Pure Virtual Methods
    // (must be implemented by derived class)
    //===================================
    // Accumulate transaction into in-progress sequence; call _enqueue() when complete
    pure virtual protected task _process(input TRANSACTION_T transaction);

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="collector");
        super.new(name);
        // WORKAROUND-INIT-PROPS {
        //     Provide/repeat default assignments for all remaining instance properties here.
        //     Works around an apparent object initialization bug (as of Vivado 2024.2)
        //     where properties are not properly allocated when they are not assigned
        //     in the constructor.
        this.__cnt_in = 0;
        this.__cnt_out = 0;
        this.inbox = null;
        this.outbox = null;
        // } WORKAROUND-INIT-PROPS
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

    // Return number of individual transactions received
    function automatic int num_input_transactions();
        return __cnt_in;
    endfunction

    // Return number of complete sequences produced
    function automatic int num_output_sequences();
        return __cnt_out;
    endfunction

    // Build component
    // [[ implements std_verif_pkg::component._build() ]]
    virtual protected function automatic void _build();
        // Nothing to do typically
    endfunction

    // Reset collector state
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

    // Initialize component for processing
    // [[ implements std_verif_pkg::component._init() ]]
    virtual protected task _init();
        // Nothing to do typically
    endtask

    // Enqueue completed sequence to outbox
    protected task _enqueue(input SEQUENCE_T seq);
        trace_msg("_enqueue()");
        debug_msg($sformatf("Enqueueing sequence #%0d.", __cnt_out+1));
        outbox.put(seq);
        __cnt_out++;
        trace_msg("_enqueue() Done.");
    endtask

    // Collector process - receive individual transactions and assemble into sequences
    // [[ implements std_verif_pkg::component._run() ]]
    protected task _run();
        trace_msg("_run()");
        info_msg("Running...");
        forever begin
            TRANSACTION_T transaction;
            inbox.get(transaction);
            __cnt_in++;
            debug_msg($sformatf("Processing transaction '%s'. ---", transaction.get_name()));
            _process(transaction);
        end
        trace_msg("_run() Done.");
    endtask

endclass : collector
