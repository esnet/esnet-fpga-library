class packet_intf_monitor #(
    parameter int DATA_BYTE_WID = 8,
    parameter type META_T = bit
) extends packet_monitor#(META_T);

    local static const string __CLASS_NAME = "packet_verif_pkg::packet_intf_monitor";

    localparam int META_WID = $bits(META_T);
    localparam int MTY_WID = DATA_BYTE_WID > 1 ? $clog2(DATA_BYTE_WID) : 1;

    //===================================
    // Properties
    //===================================
    local real __stall_rate;

    //===================================
    // Interfaces
    //===================================
    virtual packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) packet_vif;

    // Constructor
    function new(input string name="packet_intf_monitor");
        super.new(name);
        _reset();
        // WORKAROUND-INIT-PROPS {
        //     Provide/repeat default assignments for all remaining instance properties here.
        //     Works around an apparent object initialization bug (as of Vivado 2024.2)
        //     where properties are not properly allocated when they are not assigned
        //     in the constructor.
        packet_vif = null;
        // } WORKAROUND-INIT-PROPS
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        packet_vif = null;
        super.destroy();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Set stall ratio value used by driver (for stalling transmit transactions)
    function automatic void set_stall_rate(input real stall_rate);
        if (stall_rate > 1.0)      this.__stall_rate = 1.0;
        else if (stall_rate < 0.0) this.__stall_rate = 0.0;
        else                       this.__stall_rate = stall_rate;
    endfunction

    // Evaluate stall
    function automatic bit stall();
        int unsigned _stall_val = $ceil(this.__stall_rate * 32'hffffffff);
        int unsigned _rand_val = $urandom();
        if (this.__stall_rate >= 1.0) return 1;
        else if (this.__stall_rate <= 0.0) return 0;
        else return _rand_val < _stall_val;
    endfunction

    // Reset state
    // [[ overrides std_verif_pkg::monitor._reset() ]]
    virtual protected function automatic void _reset();
        set_stall_rate(0.0);
        super._reset();
    endfunction

    //===================================
    // Clocking-block interface control and transfers
    //===================================
    // Put packet monitor interface in idle state
    // [[ implements std_verif_pkg::component._idle() ]]
    protected task _idle();
        packet_vif.cb_rx.rdy <= 1'b0;
    endtask

    task flush();
        packet_vif.cb_rx.rdy <= 1'b1;
    endtask

    task wait_n(input int cycles);
        repeat (cycles) @(packet_vif.cb_rx);
    endtask

    task receive_beat(
            output bit [0:DATA_BYTE_WID-1][7:0] _data,
            output bit                _eop,
            output bit [MTY_WID-1:0]  _mty,
            output bit                _err,
            output bit [META_WID-1:0] _meta
        );
        packet_vif.cb_rx.rdy <= 1'b1;
        @(packet_vif.cb_rx iff (packet_vif.cb_rx.vld && packet_vif.cb_rx.mon_rx_rdy));
        packet_vif.cb_rx.rdy <= 1'b0;
        _data = packet_vif.cb_rx.data;
        _eop = packet_vif.cb_rx.eop;
        _mty = packet_vif.cb_rx.mty;
        _err = packet_vif.cb_rx.err;
        _meta = packet_vif.cb_rx.meta;
    endtask

    //===================================
    // Packet assembly
    //===================================
    // Receive transaction (represented as raw byte array with associated metadata)
    protected task _receive_raw(
            output byte   data[],
            output META_T meta,
            output bit    err
        );
        // Signals
        byte __data[$];
        bit [0:DATA_BYTE_WID-1][7:0] _data;
        bit  eop = 0;
        bit  __err;
        bit [MTY_WID-1:0] mty;
        int byte_idx = 0;
        int word_idx = 0;
        int byte_cnt = 0;

        debug_msg("receive_raw: Waiting for data...");

        while (!eop) begin
            if (stall()) begin
                _idle();
                wait_n(1);
            end else begin
                receive_beat(_data, eop, mty, __err, meta);
                trace_msg($sformatf("receive_raw: Received word %0d.", word_idx));
                while (byte_idx < DATA_BYTE_WID) begin
                    if (!eop || (byte_idx < DATA_BYTE_WID - mty)) begin
                        __data.push_back(_data[byte_idx]);
                        byte_idx++;
                    end else break;
                end
                byte_cnt += byte_idx;
                if (byte_cnt > this.get_max_pkt_size()) begin
                    error_msg($sformatf("Received packet exceeded MAX_PKT_SIZE limit (%0d)", this.get_max_pkt_size()));
                    $fatal(2, "Received packet exceeded MAX_PKT_SIZE limit.");
                end
                byte_idx = 0;
                word_idx++;
            end
        end
        data = __data;
        err = __err;
        __data.delete();
        debug_msg($sformatf("receive_raw: Done. Received %0d bytes.", byte_cnt));
    endtask

endclass : packet_intf_monitor
