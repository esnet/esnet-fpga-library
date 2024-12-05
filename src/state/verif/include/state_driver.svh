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
        // WORKAROUND-INIT-PROPS {
        //     Provide/repeat default assignments for all remaining instance properties here.
        //     Works around an apparent object initialization bug (as of Vivado 2024.2)
        //     where properties are not properly allocated when they are not assigned
        //     in the constructor.
        this.update_vif = null;
        // } WORKAROUND-INIT-PROPS
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        update_vif = null;
        super.destroy();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Put (driven) state update interface in idle state
    // [[ implements std_verif_pkg::.component._idle() ]]
    virtual protected task _idle();
        update_vif.idle_tx();
    endtask

    // Wait for interface to be ready to accept transactions (after reset/init, for example)
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
    protected task _send(
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
