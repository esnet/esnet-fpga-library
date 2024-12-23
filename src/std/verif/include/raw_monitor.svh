class raw_monitor #(
    parameter type DATA_T = bit[15:0]
) extends monitor#(raw_transaction#(DATA_T));

    local static const string __CLASS_NAME = "std_verif_pkg::raw_monitor";

    //===================================
    // Properties
    //===================================
    virtual std_raw_intf #(DATA_T) raw_vif;

    local rx_mode_t __rx_mode = RX_MODE_RECEIVE;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="raw_monitor");
        super.new(name);
        // WORKAROUND-INIT-PROPS {
        //     Provide/repeat default assignments for all remaining instance properties here.
        //     Works around an apparent object initialization bug (as of Vivado 2024.2)
        //     where properties are not properly allocated when they are not assigned
        //     in the constructor.
        this.raw_vif = null;
        this.__rx_mode = RX_MODE_RECEIVE;
        // } WORKAROUND-INIT-PROPS
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        raw_vif = null;
        super.destroy();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Set RX mode
    function automatic void set_rx_mode(input rx_mode_t rx_mode);
        this.__rx_mode = rx_mode;
    endfunction

    // Quiesce monitored interface
    // [[ implements std_verif_pkg::component._idle() ]]
    protected task _idle();
        raw_vif.idle_rx();
    endtask

    // Receive raw data from interface
    task receive_raw(output DATA_T data);
        trace_msg("receive_raw()");
        // Receive transaction from interface
        case (this.__rx_mode)
            RX_MODE_RECEIVE   : raw_vif.receive(data);
            RX_MODE_PULL      : raw_vif.pull(data);
            RX_MODE_ACK       : raw_vif.ack(data);
            RX_MODE_FETCH     : raw_vif.fetch(data);
            RX_MODE_FETCH_VAL : raw_vif.fetch_val(data);
            RX_MODE_ACK_FETCH : raw_vif.ack_fetch(data);
        endcase
        trace_msg("receive_raw() Done.");
    endtask

    // Receive raw transaction
    // [[ implements std_verif_pkg::monitor._receive ]]
    protected task _receive(output TRANSACTION_T transaction);
        DATA_T rx_data;

        trace_msg("_receive()");

        debug_msg("Waiting for transaction...");

        receive_raw(rx_data);

        transaction = new(
            $sformatf("raw_transaction[%0d]", num_transactions()),
            rx_data
        );

        debug_msg($sformatf("Received %s.\n%s", transaction.get_name(), transaction.to_string()));

        trace_msg("_receive() Done.");
    endtask

endclass : raw_monitor
