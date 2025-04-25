class packet_intf_monitor #(
    parameter int DATA_BYTE_WID = 8,
    parameter type META_T = logic
) extends packet_monitor#(META_T);

    local static const string __CLASS_NAME = "packet_verif_pkg::packet_intf_monitor";

    //===================================
    // Properties
    //===================================
    local bit __BIGENDIAN;
    local real __stall_rate;

    //===================================
    // Interfaces
    //===================================
    virtual packet_intf #(DATA_BYTE_WID,META_T) packet_vif;

    //===================================
    // Typedefs
    //===================================
    typedef logic [DATA_BYTE_WID-1:0][7:0] data_t;
    typedef logic [$clog2(DATA_BYTE_WID)-1:0] mty_t;

    // Constructor
    function new(input string name="packet_intf_monitor", input bit BIGENDIAN=1);
        super.new(name);
        this.__BIGENDIAN = BIGENDIAN;
        _reset();
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
        int _stall_val = $ceil(this.__stall_rate * 32'hffffffff);
        int _rand_val = $urandom();
        return _rand_val < _stall_val;
    endfunction

    // Reset state
    // [[ overrides std_verif_pkg::monitor._reset() ]]
    virtual protected function automatic void _reset();
        set_stall_rate(0.0);
        super._reset();
    endfunction

    // Put packet monitor interface in idle state
    // [[ implements std_verif_pkg::component._idle() ]]
    virtual protected task _idle();
        packet_vif.idle_rx();
    endtask

    // Receive transaction (represented as raw byte array with associated metadata)
    protected task _receive_raw(
            output byte    data[],
            output META_T  meta,
            output bit     err
        );
        // Signals
        automatic byte __data[$];
        automatic data_t _data;
        automatic logic  eop = 0;
        automatic logic  __err;
        automatic mty_t  mty;
        automatic int byte_idx = 0;
        automatic int word_idx = 0;
        automatic int byte_cnt = 0;

        debug_msg("receive_raw: Waiting for data...");

        while (!eop) begin
            packet_vif.receive(_data, eop, mty, __err, meta);
            trace_msg($sformatf("receive_raw: Received word %0d.", word_idx));
            if (this.__BIGENDIAN) begin
                _data = {<<byte{_data}};
            end
            while (byte_idx < DATA_BYTE_WID) begin
                if (!eop || (byte_idx < DATA_BYTE_WID - mty)) begin
                    __data.push_back(_data[byte_idx]);
                    byte_idx++;
                end else break;
            end
            byte_cnt += byte_idx;
            byte_idx = 0;
            word_idx++;
            while (stall()) packet_vif._wait(1);
        end
        data = __data;
        err = __err;
        __data.delete();
        debug_msg($sformatf("receive_raw: Done. Received %0d bytes.", byte_cnt));
    endtask

    task flush();
        packet_vif.flush();
    endtask

endclass : packet_intf_monitor
