// Base driver class for verification
// - abstract class (can't be instantiated directly)
// - describes interface for 'generic' driver, where methods are to be implemented by derived class
virtual class driver #(parameter type TRANSACTION_T = transaction) extends component;

    local static const string __CLASS_NAME = "std_verif_pkg::driver";

    //===================================
    // Properties
    //===================================
    local int __cnt;

    mailbox #(TRANSACTION_T) inbox;

    //===================================
    // Pure Virtual Methods
    // (must be implemented by derived class)
    //===================================
    pure virtual protected task _send(input TRANSACTION_T transaction); // Send transaction on interface

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="driver");
        super.new(name);
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        inbox = null;
        super.destroy();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Return number of transactions sent
    function automatic int num_transactions();
        return __cnt;
    endfunction

    // Build component
    // [[ implements std_verif_pkg::component._build() ]]
    virtual protected function automatic void _build();
        // Nothing to do typically
    endfunction

    // Reset driver
    // [[ implements std_verif_pkg::component._reset() ]]
    virtual protected function automatic void _reset();
        __cnt = 0;
    endfunction

    // Initialize component for processing
    // [[ implements std_verif_pkg::component._init() ]]
    virtual protected task _init();
        // Nothing to do typically
    endtask

    // Send transaction
    task send(input TRANSACTION_T transaction);
        trace_msg("send()");
        _send(transaction);
        __cnt++;
        trace_msg("send() Done.");
    endtask

    // Driver process - receive transactions from inbox and send to interface
    // [[ implements std_verif_pkg::component._run() ]]
    protected task _run();
        trace_msg("_run()");
        info_msg("Starting...");
        forever begin
            TRANSACTION_T transaction;
            debug_msg("Waiting for transaction.");
            inbox.get(transaction);
            debug_msg($sformatf("Sending transaction '%s'. ---", transaction.get_name()));
            send(transaction);
        end
        trace_msg("_run() Done.");
    endtask

endclass : driver
