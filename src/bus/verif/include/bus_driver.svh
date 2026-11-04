class bus_driver #(
    parameter type DATA_T = bit[15:0]
) extends std_verif_pkg::driver#(std_verif_pkg::raw_transaction#(DATA_T));

    local static const string __CLASS_NAME = "bus_verif_pkg::bus_driver";

    localparam int DATA_WID = $bits(DATA_T);
    //===================================
    // Properties
    //===================================
    virtual bus_intf #(DATA_WID) bus_vif;

    local tx_mode_t __tx_mode = TX_MODE_SEND;
    bit __stall = 1'b0;
    int __stall_cycles = 0;
    int __stall_cycles_max = 4; 

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

    // Set TX mode
    function automatic void set_tx_mode(input tx_mode_t tx_mode);
        this.__tx_mode = tx_mode;
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

    // Reset driver
    // [[ overrides std_verif_pkg::driver._reset() ]]
    protected function automatic void _reset();
        disable_stalls();
        super._reset();
    endfunction

    //===================================
    // Clocking-block interface control and transfers
    //===================================
    // Quiesce driven interface
    // [[ implements std_verif_pkg::component._idle() ]]
    protected task _idle();
        bus_vif.cb.valid <= 1'b0;
        bus_vif.cb.data  <= '0;
    endtask

    // Block for N cycles
    local task _wait_cycles(input int cycles);
        repeat (cycles) @(bus_vif.cb);
    endtask

    // Send
    // - indicate data to send regardless of readiness
    // - transaction is completed when both valid and
    //   ready are asserted on a particular cycle
    local task _bus_send(input bit [DATA_WID-1:0] data);
        bus_vif.cb.valid <= 1'b1;
        bus_vif.cb.data  <= data;
        @(bus_vif.cb iff (bus_vif.cb.mon_valid && bus_vif.cb.mon_ready));
        bus_vif.cb.valid <= 1'b0;
    endtask

    // Push
    // - send data to interface, ignoring ready indication
    // - transaction is completed on cycle that valid is
    //   asserted, regardless of ready value
    local task _bus_push(input bit [DATA_WID-1:0] data);
        bus_vif.cb.valid <= 1'b1;
        bus_vif.cb.data  <= data;
        @(bus_vif.cb iff (bus_vif.cb.mon_valid));
        bus_vif.cb.valid <= 1'b0;
    endtask

    // Push when ready
    // - Push data to interface, but only after interface signals
    //   readiness to receive it
    // - transaction is completed on cycle that valid is asserted
    local task _bus_push_when_ready(input bit [DATA_WID-1:0] data);
        // Observe readiness after any preceding push has updated the receiver.
        @(bus_vif.cb iff (bus_vif.cb.mon_ready));
        _bus_push(data);
    endtask

    //===================================
    // Raw-payload API
    //===================================
    // Send data to interface
    task send_raw(DATA_T data);
        int stall_cycles = 0;
        trace_msg("send_raw()");
        // Model stalls
        if (this.__stall) begin
            if (this.__stall_cycles > 0) stall_cycles = this.__stall_cycles;
            else                         stall_cycles = $urandom_range(0, this.__stall_cycles_max);
            _idle();
            _wait_cycles(stall_cycles);
        end
        // Send transaction to interface
        case(this.__tx_mode)
            TX_MODE_SEND:            _bus_send(data);
            TX_MODE_PUSH:            _bus_push(data);
            TX_MODE_PUSH_WHEN_READY: _bus_push_when_ready(data);
            default:                 _bus_send(data);
        endcase
        trace_msg("send_raw() Done.");
    endtask

    //===================================
    // Transaction-object adapter
    //===================================
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
