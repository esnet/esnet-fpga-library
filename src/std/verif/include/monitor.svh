// Base monitor class for verification
// - interface class (not to be implemented directly)
// - describes interface for 'generic' monitor, where methods are to be
//   implemented by derived class
class monitor #(
    parameter type TRANSACTION_T = transaction
) extends component;

    local static const string __CLASS_NAME = "std_verif_pkg::monitor";

    //===================================
    // Properties
    //===================================
    local int __cnt;
    local string __rx_transaction_prefix;

    mailbox #(TRANSACTION_T) outbox;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="monitor");
        super.new(name);
        this.__rx_transaction_prefix = $sformatf("%s_rx", name);
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

    // Reset monitor state
    // [[ implements std_verif_pkg::component.reset() ]]
    function automatic void reset();
        trace_msg("reset()");
        __cnt = 0;
        _reset();
        trace_msg("reset() Done.");
    endfunction

    // Receive (single) transaction
    task receive(output TRANSACTION_T transaction);
        trace_msg("receive()");
        _receive(transaction);
        __cnt++;
        trace_msg("receive() Done.");
    endtask

    // Monitor process - receive transactions from interface and send to outbox
    // [[ implements std_verif_pkg::component._start() ]]
    task _start();
        trace_msg("_start()");
        info_msg("Running...");
        forever begin
            TRANSACTION_T transaction;
            receive(transaction);
            transaction.set_name($sformatf("%s[%0d]", __rx_transaction_prefix, num_transactions()));
            outbox.put(transaction);
        end
        trace_msg("_start() Done.");
    endtask

    //===================================
    // Virtual Methods
    // (to be implemented by derived class)
    //===================================
    // Reset monitor state
    virtual function automatic void _reset(); endfunction
    // Put interface in idle state
    virtual task idle(); endtask
    // Wait for specified number of 'cycles' on the monitored interface
    virtual task _wait(input int cycles); endtask
    // Receive transaction
    virtual task _receive(output TRANSACTION_T transaction); endtask

endclass : monitor
