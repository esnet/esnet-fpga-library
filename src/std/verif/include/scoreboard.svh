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
    // Methods
    //===================================
    // Constructor
    function new(input string name="scoreboard");
        super.new(name);
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
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

    // Reset scoreboard state (public 'wrapper' method with common accounting/reporting functions)
    // (calls _reset() method of derived class to allow for application-specific behaviour)
    // [[ implements std_verif_pkg::component.reset() ]]
    function automatic void reset();
        TRANSACTION_T transaction;
        trace_msg("reset()");
        _reset();
        while (got_inbox.try_get(transaction));
        while (exp_inbox.try_get(transaction));
        __processed_cnt = 0;
        __match_cnt = 0;
        __mismatch_cnt = 0;
        __unmatched_cnt = 0;
        __got_cnt = 0;
        __exp_cnt = 0;
        trace_msg("reset() Done.");
    endfunction

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

    //===================================
    // Virtual Methods
    //===================================
    // Reset scoreboard state
    protected virtual function automatic void _reset(); endfunction
    // Post-process results
    protected virtual function automatic void _postprocess(); endfunction

endclass : scoreboard
