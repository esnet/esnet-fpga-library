class packet_monitor #(
    parameter int DATA_BYTE_WID = 8,
    parameter type META_T = bit
) extends std_verif_pkg::monitor#(packet#(META_T));

    local static const string __CLASS_NAME = "packet_verif_pkg::packet_monitor";

    //===================================
    // Properties
    //===================================
    protected bit _BIGENDIAN;
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

    // Constructor
    function new(input string name="packet_monitor", input bit BIGENDIAN=1);
        super.new(name);
        this._BIGENDIAN = BIGENDIAN;
        this._stall_rate = 0.0;
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
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

    // Reset monitor state
    // [[ implements _reset() virtual method of std_verif_pkg::monitor parent class ]]
    function automatic void _reset();
        // Nothing to do
    endfunction

    // Put packet monitor interface in idle state
    // [[ implements std_verif_pkg::monitor.idle() ]]
    task idle();
        packet_vif.idle_rx();
    endtask

    // Wait for specified number of 'cycles' on the monitored interface
    // [[ implements std_verif_pkg::monitor._wait() ]]
    task _wait(input int cycles);
        packet_vif._wait(cycles);
    endtask

    // Receive transaction (represented as raw byte array with associated metadata)
    task receive_raw(
            output byte    data[$],
            output META_T  meta,
            output bit     err
        );
        // Signals
        data_t _data;
        bit    eop = 0;
        mty_t  mty;
        bit tlast = 0;
        int byte_idx = 0;
        int word_idx = 0;
        int byte_cnt = 0;

        debug_msg("receive_raw: Waiting for data...");

        while (!eop) begin
            packet_vif.receive(_data, eop, mty, err, meta);
            trace_msg($sformatf("receive_raw: Received word %0d.", word_idx));
            if (_BIGENDIAN) begin
                _data = {<<byte{_data}};
            end
            while (byte_idx < DATA_BYTE_WID) begin
                if (!eop || (byte_idx < DATA_BYTE_WID - mty)) begin
                    data.push_back(_data[byte_idx]);
                    byte_idx++;
                end else break;
            end
            byte_cnt += byte_idx;
            byte_idx = 0;
            word_idx++;
        end
        debug_msg($sformatf("receive_raw: Done. Received %0d bytes.", byte_cnt));
    endtask


    // Receive packet transaction from packet interface
    // [[ implements _receive() virtual method of std_verif_pkg::monitor parent class ]]
    // [[ implements std_verif_pkg::monitor._receive() ]]
    task _receive(
            output packet#(META_T) transaction
        );
        // Signals
        byte data [];
        bit err;
        META_T meta;

        packet_verif_pkg::packet_raw packet;

        debug_msg("Waiting for transaction...");

        // Receive transaction
        receive_raw(data, meta, err);

        // Build Rx packet transaction
        transaction = packet_verif_pkg::packet_raw#(META_T)::create_from_bytes("rx_packet", data, meta, err);

        debug_msg($sformatf("Received %s (%0d bytes).", transaction.get_name(), transaction.size()));
    endtask

    task flush();
        packet_vif.flush();
    endtask

endclass
