class packet_intf_driver #(
    parameter int DATA_BYTE_WID = 8,
    parameter type META_T = bit
) extends packet_driver#(META_T);

    local static const string __CLASS_NAME = "packet_verif_pkg::packet_intf_driver";

    //===================================
    // Properties
    //===================================
    protected bit _BIGENDIAN;
    protected int _min_pkt_gap;
    protected real _stall_rate;

    //===================================
    // Interfaces
    //===================================
    virtual packet_intf #(
        .DATA_BYTE_WID(DATA_BYTE_WID),
        .META_T(META_T)
    ) packet_vif;

    //===================================
    // Typedefs
    //===================================
    typedef bit [DATA_BYTE_WID-1:0][7:0] data_t;
    typedef bit [$clog2(DATA_BYTE_WID)-1:0] mty_t;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="packet_intf_driver", input bit BIGENDIAN=1);
        super.new(name);
        this._BIGENDIAN = BIGENDIAN;
        this._stall_rate = 0.0;
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Set minimum inter-packet gap (in clock cycles)
    function automatic void set_min_gap(input int min_pkt_gap);
        this._min_pkt_gap = min_pkt_gap;
    endfunction

    // Set stall ratio value used by driver (for stalling transmit transactions)
    function automatic void set_stall_rate(input real stall_rate);
        if (stall_rate > 1.0)      this._stall_rate = 1.0;
        else if (stall_rate < 0.0) this._stall_rate = 0.0;
        else                       this._stall_rate = stall_rate;
    endfunction

    // Evaluate stall
    function automatic bit stall();
        int _stall_val = $ceil(this._stall_rate * 32'hffffffff);
        int _rand_val = $urandom();
        return _rand_val < _stall_val;
    endfunction

    // Reset driver state
    // [[ implements std_verif_pkg::driver._reset() ]]
    function automatic void _reset();
        // Nothing to do
    endfunction

    // Put (driven) packet interface in idle state
    // [[ implements std_verif_pkg::driver.idle() ]]
    task idle();
        packet_vif.idle_tx();
    endtask

    // Wait for specified number of 'cycles' on the driven interface
    // [[ implements std_verif_pkg::driver._wait() ]]
    task _wait(input int cycles);
        packet_vif._wait(cycles);
    endtask

    // Wait for interface to be ready to accept transactions (after reset/init, for example)
    // [[ implements std_verif_pkg::driver.wait_ready() ]]
    task wait_ready();
        bit timeout;
        packet_vif.wait_ready(timeout, 0);
    endtask

    // Send packet (represented as raw byte array with associated metadata)
    // [[ implements packet_verif_pkg::packet_driver._send_raw() ]]
    task send_raw(
            input byte    data[],
            input META_T  meta = '0,
            input bit     err = 1'b0
        );
        // Signals
        automatic byte __data[$] = data;
        automatic data_t _data = '0;
        automatic mty_t  mty;
        automatic bit    eop;
        automatic int byte_idx = 0;
        automatic int word_idx = 0;

        debug_msg($sformatf("send_raw: Sending %0d bytes...", data.size()));
        // Send
        while (__data.size() > 0) begin
            _data[byte_idx] = __data.pop_front();
            eop = 0;
            mty = 0;
            byte_idx++;
            if ((byte_idx == DATA_BYTE_WID) || (__data.size() == 0)) begin
                if (_BIGENDIAN) begin
                    _data = {<<byte{_data}};
                end
                if (__data.size() == 0) begin
                    eop = 1'b1;
                    mty = DATA_BYTE_WID - byte_idx;
                end
                trace_msg($sformatf("send_raw: Sending word %0d.", word_idx));
                packet_vif.send(_data, eop, mty, err, meta);
                _data = '0;
                byte_idx = 0;
                word_idx++;
                while (stall()) _wait(1);
            end
        end
        debug_msg("send_raw: Done.");
        idle();
        _wait(this._min_pkt_gap);
    endtask

endclass : packet_intf_driver
