// Sequencer class for verification
// - abstract class (can't be instantiated directly)
// - decomposes high-level sequence objects into ordered individual transactions
// - 1:N mapping: one sequence in, N transactions out via outbox
virtual class sequencer #(
    parameter type SEQUENCE_T    = transaction,
    parameter type TRANSACTION_T = SEQUENCE_T
) extends component;

    local static const string __CLASS_NAME = "std_verif_pkg::sequencer";

    //===================================
    // Properties
    //===================================
    local int __seq_cnt = 0;
    local int __transaction_cnt = 0;

    mailbox #(SEQUENCE_T)    inbox;
    mailbox #(TRANSACTION_T) outbox;

    //===================================
    // Pure Virtual Methods
    // (must be implemented by derived class)
    //===================================
    // Decompose sequence into individual transactions by calling _enqueue() for each
    pure virtual protected task _generate(input SEQUENCE_T seq);

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="sequencer");
        super.new(name);
        // WORKAROUND-INIT-PROPS {
        //     Provide/repeat default assignments for all remaining instance properties here.
        //     Works around an apparent object initialization bug (as of Vivado 2024.2)
        //     where properties are not properly allocated when they are not assigned
        //     in the constructor.
        this.__seq_cnt = 0;
        this.__transaction_cnt = 0;
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

    // Return number of sequences processed
    function automatic int num_sequences();
        return __seq_cnt;
    endfunction

    // Return number of transactions produced
    function automatic int num_transactions();
        return __transaction_cnt;
    endfunction

    // Build component
    // [[ implements std_verif_pkg::component._build() ]]
    virtual protected function automatic void _build();
        // Nothing to do typically
    endfunction

    // Reset sequencer state
    // [[ implements std_verif_pkg::component._reset() ]]
    virtual protected function automatic void _reset();
        __seq_cnt = 0;
        __transaction_cnt = 0;
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

    // Dequeue next sequence from inbox
    protected task _dequeue(output SEQUENCE_T seq);
        trace_msg("_dequeue()");
        debug_msg($sformatf("Waiting to dequeue sequence #%0d.", __seq_cnt+1));
        inbox.get(seq);
        __seq_cnt++;
        trace_msg("_dequeue() Done.");
    endtask

    // Enqueue transaction to outbox
    protected task _enqueue(input TRANSACTION_T transaction);
        trace_msg("_enqueue()");
        debug_msg($sformatf("Enqueueing transaction #%0d.", __transaction_cnt+1));
        outbox.put(transaction);
        __transaction_cnt++;
        trace_msg("_enqueue() Done.");
    endtask

    // Sequencer process - receive sequences from inbox and decompose into transactions
    // [[ implements std_verif_pkg::component._run() ]]
    protected task _run();
        trace_msg("_run()");
        info_msg("Starting...");
        forever begin
            SEQUENCE_T seq;
            _dequeue(seq);
            debug_msg($sformatf("Sequencing '%s'. ---", seq.get_name()));
            _generate(seq);
        end
        trace_msg("_run() Done.");
    endtask

endclass : sequencer
