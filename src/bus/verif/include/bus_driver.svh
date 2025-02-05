class bus_driver #(
    parameter type DATA_T = bit[15:0]
) extends std_verif_pkg::driver#(std_verif_pkg::raw_transaction#(DATA_T));

    local static const string __CLASS_NAME = "bus_verif_pkg::bus_driver";

    //===================================
    // Properties
    //===================================
    virtual bus_intf #(DATA_T) bus_vif;

    local tx_mode_t __tx_mode = TX_MODE_SEND;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="bus_driver");
        super.new(name);
        // WORKAROUND-INIT-PROPS {
        //     Provide/repeat default assignments for all remaining instance properties here.
        //     Works around an apparent object initialization bug (as of Vivado 2024.2)
        //     where properties are not properly allocated when they are not assigned
        //     in the constructor.
        this.bus_vif = null;
        this.__tx_mode = TX_MODE_SEND;
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

    // Set TX mode
    function automatic void set_tx_mode(input tx_mode_t tx_mode);
        this.__tx_mode = tx_mode;
    endfunction

    // Quiesce driven interface
    // [[ implements std_verif_pkg::component._idle() ]]
    protected task _idle();
        bus_vif.idle_tx();
    endtask

    // Send data to interface
    task send_raw(DATA_T data);
        trace_msg("send_raw()");
        // Send transaction to interface
        case(this.__tx_mode)
            TX_MODE_SEND:            bus_vif.send(data);
            TX_MODE_PUSH:            bus_vif.push(data);
            TX_MODE_PUSH_WHEN_READY: bus_vif.push_when_ready(data);
            default:                 bus_vif.send(data);
        endcase
        trace_msg("send_raw() Done.");
    endtask

    // Send bus transaction
    // [[ implements std_verif_pkg::driver._send() ]]
    protected task _send(input TRANSACTION_T transaction);
        trace_msg("_send()");
        info_msg($sformatf("Sending transaction '%s'", transaction.get_name()));
        debug_msg($sformatf("\t%s", transaction.to_string));
        send_raw(transaction.data);
        trace_msg("_send() Done.");
    endtask

endclass : bus_driver
