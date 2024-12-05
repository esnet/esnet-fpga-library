class db_driver #(
    parameter type KEY_T = bit[15:0],
    parameter type VALUE_T = bit[31:0]
) extends std_verif_pkg::driver#(db_req_transaction#(KEY_T, VALUE_T));

    local static const string __CLASS_NAME = "db_verif_pkg::db_driver";

    //===================================
    // Properties
    //===================================
    virtual db_intf #(KEY_T, VALUE_T) db_vif;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="db_driver");
        super.new(name);
        // WORKAROUND-INIT-PROPS {
        //     Provide/repeat default assignments for all remaining instance properties here.
        //     Works around an apparent object initialization bug (as of Vivado 2024.2)
        //     where properties are not properly allocated when they are not assigned
        //     in the constructor.
        this.db_vif = null;
        // } WORKAROUND-INIT-PROPS
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Reset driver state
    // [[ implements std_verif_pkg::driver._reset() ]]
    function automatic void _reset();
        trace_msg("_reset()");
        // Nothing to do
        trace_msg("_reset() Done.");
    endfunction

    // Put (driven) database update interface in idle state
    // [[ implements std_verif_pkg::driver.idle() ]]
    task idle();
        db_vif.idle();
    endtask

    // Wait for specified number of 'cycles' on the driven interface
    // [[ implements std_verif_pkg::driver._wait() ]]
    task _wait(input int cycles);
        db_vif._wait(cycles);
    endtask

    // Wait for interface to be ready to accept transactions (after reset/init, for example)
    // [[ implements std_verif_pkg::driver.wait_ready() ]]
    task wait_ready();
        automatic bit no_timeout;
        trace_msg("wait_ready()");
        db_vif.wait_ready(no_timeout, 0);
        trace_msg("wait_ready() Done.");
    endtask

    task send_raw(
            input KEY_T key
        );
        trace_msg("send_raw()");
        // Send transaction to interface
        db_vif.send(key);
        trace_msg("send_raw() Done.");
    endtask

    // Send database transaction
    // [[ implements std_verif_pkg::driver._send() ]]
    task _send(input db_req_transaction transaction);
        trace_msg("_send()");
        info_msg($sformatf("Sending transaction '%s'", transaction.get_name()));

        send_raw(transaction.key);
        
        info_msg("Done.");
        trace_msg("_send() Done.");
    endtask

endclass : db_driver
