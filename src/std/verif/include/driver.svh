// Base driver class for verification
// - interface class (not to be implemented directly)
// - describes interface for 'generic' driver, where methods are to be
//   implemented by derived class
class driver #(
    parameter type TRANSACTION_T = transaction
) extends component;

    local static const string __CLASS_NAME = "std_verif_pkg::driver";

    //===================================
    // Properties
    //===================================
    local int __cnt;
    local event __stop;

    mailbox #(TRANSACTION_T) inbox;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="driver");
        super.new(name);
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

    // Reset driver state
    // [[ implements std_verif_pkg::component.reset() ]]
    function automatic void reset();
        trace_msg("reset()");
        __cnt = 0;
        _reset();
        trace_msg("reset() Done.");
    endfunction

    // Send transaction
    task send(input TRANSACTION_T transaction);
        trace_msg("send()");
        _send(transaction);
        __cnt++;
        trace_msg("send() Done.");
    endtask

    // Driver process - receive transactions from inbox and send to interface
    // [[ implements std_verif_pkg::component._start() ]]
    task _start();
        trace_msg("_start()");
        info_msg("Starting...");
        forever begin
            TRANSACTION_T transaction;
            debug_msg("Waiting for transaction.");
            inbox.get(transaction);
            debug_msg($sformatf("Sending transaction '%s'. ---", transaction.get_name()));
            send(transaction);
        end
        trace_msg("_start() Done.");
    endtask

    //===================================
    // Virtual Methods
    // (to be implemented by derived class)
    //===================================
    // Reset driver state
    protected virtual function automatic void _reset(); endfunction
    // Put (driven) interface in idle state
    virtual task idle(); endtask
    // Wait for specified number of 'cycles' on the driven interface
    protected virtual task _wait(input int cycles); endtask
    // Wait for interface to be ready to accept transactions (after reset/init, for example)
    virtual task wait_ready(); endtask
    // Send transaction
    protected virtual task _send(input TRANSACTION_T transaction); endtask

endclass : driver
