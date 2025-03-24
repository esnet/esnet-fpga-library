class bus_monitor #(
    parameter type DATA_T = bit[15:0]
) extends std_verif_pkg::monitor#(std_verif_pkg::raw_transaction#(DATA_T));

    local static const string __CLASS_NAME = "bus_verif_pkg::bus_monitor";

    //===================================
    // Properties
    //===================================
    virtual bus_intf #(DATA_T) bus_vif;

    local rx_mode_t __rx_mode = RX_MODE_RECEIVE;
    bit __stall = 1'b0;
    int __stall_cycles = 0;
    int __stall_cycles_max = 4; 

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="bus_monitor");
        super.new(name);
        // WORKAROUND-INIT-PROPS {
        //     Provide/repeat default assignments for all remaining instance properties here.
        //     Works around an apparent object initialization bug (as of Vivado 2024.2)
        //     where properties are not properly allocated when they are not assigned
        //     in the constructor.
        this.bus_vif = null;
        this.__rx_mode = RX_MODE_RECEIVE;
        this.__stall = 1'b0;
        this.__stall_cycles = 0;
        this.__stall_cycles_max = 4;
        // } WORKAROUND-INIT-PROPS
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        bus_vif = null;
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

    // Enable stalls
    function automatic void enable_stalls(input int stall_cycles=0);
        this.__stall = 1'b1;
        this.__stall_cycles = stall_cycles;
    endfunction

    function automatic void disable_stalls();
        this.__stall = 1'b0;
    endfunction

    function automatic void set_max_stall(input int max_stall);
        this.__stall_cycles_max = max_stall;
    endfunction

    // Quiesce monitored interface
    // [[ implements std_verif_pkg::component._idle() ]]
    protected task _idle();
        bus_vif.idle_rx();
    endtask

    // Receive raw data from interface
    task receive_raw(output DATA_T data);
        int stall_cycles = 0;
        trace_msg("receive_raw()");
        // Model stalls
        if (this.__stall) begin
            if (this.__stall_cycles > 0) stall_cycles = this.__stall_cycles;
            else                         stall_cycles = $urandom_range(0, this.__stall_cycles_max);
            bus_vif.idle_rx();
            bus_vif._wait(stall_cycles);
        end
        // Receive transaction from interface
        case (this.__rx_mode)
            RX_MODE_RECEIVE   : bus_vif.receive(data);
            RX_MODE_PULL      : bus_vif.pull(data);
            RX_MODE_ACK       : bus_vif.ack(data);
            RX_MODE_FETCH     : bus_vif.fetch(data);
            RX_MODE_FETCH_VAL : bus_vif.fetch_val(data);
            RX_MODE_ACK_FETCH : bus_vif.ack_fetch(data);
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

endclass : bus_monitor
