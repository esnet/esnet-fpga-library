// Base monitor class for verification
// - abstract class (can't be instantiated directly)
// - describes interface for 'generic' monitor, where methods are to be implemented by derived class
virtual class monitor #(parameter type TRANSACTION_T = transaction) extends component;

    local static const string __CLASS_NAME = "std_verif_pkg::monitor";

    //===================================
    // Properties
    //===================================
    local int __cnt = 0;
    local string __rx_transaction_prefix;

    mailbox #(TRANSACTION_T) outbox;

    //===================================
    // Pure Virtual Methods
    // (to be implemented by derived class)
    //===================================
    pure virtual protected task _receive(output TRANSACTION_T transaction); // Receive transaction on interface

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="monitor");
        super.new(name);
        this.__rx_transaction_prefix = $sformatf("%s_rx", name);
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        outbox = null;
        super.destroy();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Return number of transactions received
    function automatic int num_transactions();
        return __cnt;
    endfunction

    // Set name prefix for received transactions (suffix is receive order #)
    function automatic void set_rx_transaction_prefix(input string prefix);
        this.__rx_transaction_prefix = prefix;
    endfunction

    // Build component
    // [[ implements std_verif_pkg::component._build() ]]
    virtual protected function automatic void _build();
        // Nothing to do typically
    endfunction

    // Reset monitor
    // [[ implements std_verif_pkg::component._reset() ]]
    virtual protected function automatic void _reset();
        __cnt = 0;
    endfunction

    // Initialize component for processing
    // [[ implements std_verif_pkg::component._init() ]]
    virtual protected task _init();
        // Nothing to do typically
    endtask

    // Receive (single) transaction
    task receive(output TRANSACTION_T transaction);
        trace_msg("receive()");
        _receive(transaction);
        transaction.set_name($sformatf("%s[%0d]", __rx_transaction_prefix, num_transactions()));
        __cnt++;
        trace_msg("receive() Done.");
    endtask

    // Monitor process - receive transactions from interface and send to outbox
    // [[ implements std_verif_pkg::component._run() ]]
    protected task _run();
        trace_msg("_run()");
        info_msg("Running...");
        forever begin
            TRANSACTION_T transaction;
            receive(transaction);
            debug_msg($sformatf("Received transaction '%s'. ---", transaction.get_name()));
            outbox.put(transaction);
        end
        trace_msg("_run() Done.");
    endtask

endclass : monitor
