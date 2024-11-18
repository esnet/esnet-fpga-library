// Scoreboard class for verification
// - implements 'event-based' scoreboard component, where received and expected
//   results are compared on an event (transaction/packet/etc) basis
class event_scoreboard #(parameter type TRANSACTION_T = transaction) extends scoreboard#(TRANSACTION_T);

    local static const string __CLASS_NAME = "std_verif_pkg::event_scoreboard";

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="event_scoreboard");
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

    // Post-process results
    // [[ implements std_verif_pkg::scoreboard._postprocess() ]]
    protected function automatic void _postprocess();
        trace_msg("_postprocess()");
        // Consider all pending (unprocessed) 'expected' transactions as unmatched
        _unmatched(exp_pending());
        trace_msg("_postprocess() Done.");
    endfunction

    // Start scoreboard (run loop)
    // [[ implements std_verif_pkg::component._run() ]]
    task _run();
        trace_msg("_run()");
        forever begin
            TRANSACTION_T got_transaction;
            TRANSACTION_T exp_transaction;
            string compare_msg;
            _got_next(got_transaction);
            debug_msg($sformatf("Processed received transaction:\n%s", got_transaction.to_string()));
            _exp_next(exp_transaction);
            debug_msg($sformatf("Processed expected transaction:\n%s", exp_transaction.to_string()));
            _processed(1);
            if (exp_transaction.compare(got_transaction, compare_msg)) begin
                _matched(1);
            end else begin
                error_msg(
                    $sformatf(
                        "Mismatch while comparing transactions %s (A) and %s (B):\n%s",
                        exp_transaction.get_name(), got_transaction.get_name(), compare_msg
                    )
                );
                _mismatched(1);
            end
        end
        trace_msg("_run() Done.");
    endtask

endclass : event_scoreboard
