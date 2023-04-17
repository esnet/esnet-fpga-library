class state_driver #(
    parameter type ID_T = bit,
    parameter type STATE_T = bit,
    parameter type UPDATE_T = bit
) extends std_verif_pkg::driver#(state_req#(ID_T, UPDATE_T));

    local static const string __CLASS_NAME = "state_verif_pkg::state_driver";

    //===================================
    // Properties
    //===================================
    virtual state_intf #(ID_T, STATE_T, UPDATE_T) update_vif;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="state_driver");
        super.new(name);
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Reset driver state
    // [[ implements std_verif_pkg::driver._reset() ]]
    function automatic void _reset();
        // Nothing to do
    endfunction

    // Put (driven) state update interface in idle state
    // [[ implements std_verif_pkg::.driver.idle() ]]
    task idle();
        update_vif.idle_tx();
    endtask

    // Wait for specified number of 'cycles' on the driven interface
    // [[ implements std_verif_pkg::driver._wait() ]]
    task _wait(input int cycles);
        update_vif._wait(cycles);
    endtask

    // Wait for interface to be ready to accept transactions (after reset/init, for example)
    // [[ implements std_verif_pkg::driver.wait_ready() ]]
    task wait_ready();
        trace_msg("wait_ready()");
        update_vif.wait_ready();
        trace_msg("wait_ready() Done.");
    endtask

    // Send transaction (represented as raw data value)
    task send_raw(
            input ht_packet_data_t data
        );
        trace_msg("send_raw()");
        // Send transaction to interface
        update_vif.push(data);
        raw_vif._wait(this.__min_pkt_gap);
        trace_msg("send_raw() Done.");
    endtask

    // Send transaction to interface
    // [[ implements std_verif_pkg::driver._send() ]]
    task _send(
            input state_req#(ID_T, UPDATE_T) transaction
        );
        trace_msg("_send()");
        info_msg($sformatf("Sending transaction '%s'", transaction.get_name()));
        debug_msg($sformatf("Sending:\n%s", transaction.to_string()));

        // Send transaction
        update_vif.send(transaction.id, transaction.update, transaction.init);

        trace_msg("_send() Done.");
    endtask

endclass : state_driver
