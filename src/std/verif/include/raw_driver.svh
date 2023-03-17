class raw_driver #(
    parameter type DATA_T = bit[15:0]
) extends driver#(raw_transaction#(DATA_T));

    local static const string __CLASS_NAME = "std_verif_pkg::raw_driver";

    //===================================
    // Properties
    //===================================
    virtual std_raw_intf #(DATA_T) raw_vif;

    local tx_mode_t __tx_mode = TX_MODE_SEND;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="raw_driver");
        super.new(name);
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Set TX mode
    function automatic void set_tx_mode(input tx_mode_t tx_mode);
        this.__tx_mode = tx_mode;
    endfunction

    // Reset driver state
    // [[ implements std_verif_pkg::driver._reset() ]]
    function automatic void _reset();
        trace_msg("_reset()");
        // Nothing to do
        trace_msg("_reset() Done.");
    endfunction

    // Put (driven) stats update interface in idle state
    // [[ implements std_verif_pkg::driver.idle() ]]
    task idle();
        trace_msg("idle()");
        raw_vif.idle_tx();
        trace_msg("idle() Done.");
    endtask

    // Wait for specified number of 'cycles' on the driven interface
    // [[ implements std_verif_pkg::driver._wait() ]]
    task _wait(input int cycles);
        raw_vif._wait(cycles);
    endtask

    // Wait for interface to be ready to accept transactions (after reset/init, for example)
    // [[ implements std_verif_pkg::driver.wait_ready() ]]
    task wait_ready();
        trace_msg("wait_ready()");
        raw_vif.wait_ready();
        trace_msg("wait_ready() Done.");
    endtask

    // Send raw data to interface
    task send_raw(DATA_T data);
        trace_msg("send_raw()");
        // Send transaction to interface
        case(this.__tx_mode)
            TX_MODE_SEND:            raw_vif.send(data);
            TX_MODE_PUSH:            raw_vif.push(data);
            TX_MODE_PUSH_WHEN_READY: raw_vif.push_when_ready(data);
            default:                 raw_vif.send(data);
        endcase
        trace_msg("send_raw() Done.");
    endtask

    // Send raw transaction
    // [[ implements std_verif_pkg::driver._send() ]]
    task _send(input TRANSACTION_T transaction);
        trace_msg("_send()");
        info_msg($sformatf("Sending transaction '%s'", transaction.get_name()));
        debug_msg($sformatf("\t%s", transaction.to_string));
        send_raw(transaction.data);
        trace_msg("_send() Done.");
    endtask

endclass : raw_driver
