// Scoreboard class for verification
// - represents abstract base class for scoreboard, where virtual methods are
//   to be implemented by derived class
virtual class scoreboard #(parameter type TRANSACTION_T = transaction) extends component;

    local static const string __CLASS_NAME = "std_verif_pkg::scoreboard";

    //===================================
    // Properties
    //===================================
    local int __got_cnt;
    local int __exp_cnt;

    local int __processed_cnt = 0;
    local int __match_cnt = 0;
    local int __mismatch_cnt = 0;
    local int __unmatched_cnt = 0;

    mailbox #(TRANSACTION_T) got_inbox;
    mailbox #(TRANSACTION_T) exp_inbox;

    //===================================
    // Pure Virtual Methods
    // (must be implemented by derived class)
    //===================================
    // Post-process results
    pure protected virtual function automatic void _postprocess();

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="scoreboard");
        super.new(name);
        reset();
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        got_inbox = null;
        exp_inbox = null;
        super.destroy();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Build component
    // [[ implements std_verif_pkg::component._build() ]]
    virtual protected function automatic void _build();
        // Nothing to do typically
    endfunction

    // Return number of received transactions pending
    function automatic int got_pending();
        return got_inbox.num();
    endfunction

    // Return number of matched transactions
    function automatic int got_matched();
        return __match_cnt;
    endfunction

    // Return number of received transactions processed
    function automatic int got_processed();
        return __got_cnt;
    endfunction

    // Return number of expected transactions pending
    function automatic int exp_pending();
        return exp_inbox.num();
    endfunction

    // Return number of expected transactions processed
    function automatic int exp_processed();
        return __exp_cnt;
    endfunction

    protected function automatic void _processed(input int num=1);
        this.__processed_cnt += num;
    endfunction

    protected function automatic void _matched(input int num=1);
        this.__match_cnt += num;
    endfunction

    protected function automatic void _mismatched(input int num=1);
        this.__mismatch_cnt += num;
    endfunction

    protected function automatic void _unmatched(input int num=1);
        this.__unmatched_cnt += num;
    endfunction

    // Reset scoreboard
    // [[ implements std_verif_pkg::component._reset() ]]
    virtual protected function automatic void _reset();
        __processed_cnt = 0;
        __match_cnt = 0;
        __mismatch_cnt = 0;
        __unmatched_cnt = 0;
        __got_cnt = 0;
        __exp_cnt = 0;
    endfunction

    // Quiesce all interfaces
    // [[ implements std_verif_pkg::component._idle() ]]
    virtual protected task _idle();
        // Nothing to do typically
    endtask

    // Pull next 'actual' (received) transaction (blocking)
    protected task _got_next(output TRANSACTION_T transaction);
        trace_msg("_got_next()");
        got_inbox.get(transaction);
        __got_cnt++;
        trace_msg("_got_next() Done.");
    endtask

    // Pull next 'expected' (predicted) transaction (blocking)
    protected task _exp_next(output TRANSACTION_T transaction);
        trace_msg("_exp_next()");
        exp_inbox.get(transaction);
        __exp_cnt++;
        trace_msg("_exp_next() Done.");
    endtask

    // Report results
    function automatic int report(output string msg);
        string _msg = "";
        int error_cnt;
        trace_msg("report()");
        _postprocess();
        error_cnt = __mismatch_cnt + __unmatched_cnt;
        if (error_cnt > 0) _msg = {_msg, $sformatf("%s report FAILED with %0d errors.\n", get_name(), error_cnt)};
        else               _msg = {_msg, "Report PASSED.\n"};
        _msg = {_msg, "\t", {50{"="}}, "\n"};
        _msg = {_msg, $sformatf("\tProcessed : %0d\n", __processed_cnt)};
        _msg = {_msg, $sformatf("\tMatches   : %0d\n", __match_cnt)};
        _msg = {_msg, $sformatf("\tMismatches: %0d\n", __mismatch_cnt)};
        _msg = {_msg, $sformatf("\tUnmatched : %0d\n", __unmatched_cnt)};
        _msg = {_msg, "\t", {50{"="}}, "\n"};
        msg = _msg;
        info_msg(msg);
        trace_msg("report() Done.");
        return error_cnt;
    endfunction

    // Initialize scoreboard for processing
    // [[ implements std_verif_pkg::component._init() ]]
    virtual protected task _init();
        TRANSACTION_T transaction;
        // Flush unprocessed transactions
        while (got_inbox.try_get(transaction));
        while (exp_inbox.try_get(transaction));
        // Reset state
        reset();
    endtask

endclass : scoreboard
