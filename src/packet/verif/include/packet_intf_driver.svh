class packet_intf_driver #(
    parameter int DATA_BYTE_WID = 8,
    parameter type META_T = bit
) extends packet_driver#(META_T);

    local static const string __CLASS_NAME = "packet_verif_pkg::packet_intf_driver";

    localparam int META_WID = $bits(META_T);

    //===================================
    // Properties
    //===================================
    local int __min_pkt_gap;
    local real __stall_rate;

    //===================================
    // Interfaces
    //===================================
    virtual packet_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .META_WID(META_WID)) packet_vif;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="packet_intf_driver");
        super.new(name);
        this.__stall_rate = 0.0;
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

    // Set minimum inter-packet gap (in clock cycles)
    function automatic void set_min_gap(input int min_pkt_gap);
        this.__min_pkt_gap = min_pkt_gap;
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
    // [[ overrides std_verif_pkg::driver._reset() ]]
    protected virtual function automatic void _reset();
        set_stall_rate(0.0);
        super._reset();
    endfunction

    // Put (driven) packet interface in idle state
    // [[ implements std_verif_pkg::component._idle() ]]
    virtual protected task _idle();
        packet_vif.idle_tx();
    endtask

    // Send packet (represented as raw byte array with associated metadata)
    // [[ implements packet_verif_pkg::packet_driver._send_raw() ]]
    protected task _send_raw(
            const ref byte data [],
            input META_T meta = '0,
            input bit    err = 1'b0
        );
        // Parameters
        localparam int MTY_WID = $clog2(DATA_BYTE_WID);
        // Signals
        byte __data[$] = data;
        bit [0:DATA_BYTE_WID-1][7:0] _data = '0;
        bit [MTY_WID-1:0] mty;
        bit __err = err;
        bit eop;
        int byte_idx = 0;
        int word_idx = 0;

        debug_msg($sformatf("send_raw: Sending %0d bytes...", data.size()));
        // Send
        while (__data.size() > 0) begin
            _data[byte_idx] = __data.pop_front();
            eop = 0;
            mty = 0;
            byte_idx++;
            if ((byte_idx == DATA_BYTE_WID) || (__data.size() == 0)) begin
                if (__data.size() == 0) begin
                    eop = 1'b1;
                    mty = DATA_BYTE_WID - byte_idx;
                end
                trace_msg($sformatf("send_raw: Sending word %0d.", word_idx));
                packet_vif.send(_data, eop, mty, __err, meta);
                _data = '0;
                byte_idx = 0;
                word_idx++;
                while (stall()) packet_vif._wait(1);
            end
        end
        debug_msg("send_raw: Done.");
        idle();
        packet_vif._wait(this.__min_pkt_gap);
    endtask

endclass : packet_intf_driver
