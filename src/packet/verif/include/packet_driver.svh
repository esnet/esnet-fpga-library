class packet_driver #(
    parameter int DATA_BYTE_WID = 8,
    parameter type META_T = bit
) extends std_verif_pkg::driver#(packet#(META_T));

    local static const string __CLASS_NAME = "packet_verif_pkg::packet_driver";

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
    function new(input string name="packet_driver", input bit BIGENDIAN=1);
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

    // Send transaction (represented as raw byte array with associated metadata)
    task send_raw(
            input byte    data[$],
            input META_T  meta = '0,
            input bit     err = 1'b0
        );
        // Signals
        data_t _data = '0;
        mty_t  mty;
        bit    eop;
        int byte_idx = 0;
        int word_idx = 0;

        debug_msg($sformatf("send_raw: Sending %0d bytes...", data.size()));
        // Send
        while (data.size() > 0) begin
            _data[byte_idx] = data.pop_front();
            eop = 0;
            mty = 0;
            byte_idx++;
            if ((byte_idx == DATA_BYTE_WID) || (data.size() == 0)) begin
                if (_BIGENDIAN) begin
                    _data = {<<byte{_data}};
                end
                if (data.size() == 0) begin
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

    // Send packet transaction on packet interface
    // [[ implements std_verif_pkg::driver._send() ]]
    task _send(
            input packet#(META_T) transaction
        );

        debug_msg($sformatf("Sending:\n%s", transaction.to_string()));

        // Send transaction
        send_raw(transaction.to_bytes(), transaction.get_meta(), transaction.is_errored());

        debug_msg("Done.");
    endtask

    // Send packets from PCAP file as transactions on packet bus
    task send_from_pcap(
            input string pcap_filename,
            input int num_pkts=0,
            input int start_idx=0,
            input META_T meta='0
        );
        // Signals
        pcap_pkg::pcap_t pcap;
        byte pkt_data[$][$];
        int num_pcap_pkts;
        int pkt_idx;

        info_msg($sformatf("Reading packets from PCAP file %s.", pcap_filename));

        // Read packet data from PCAP file
        pcap = pcap_pkg::read_pcap(pcap_filename);

        // Get number of packets described in PCAP
        num_pcap_pkts = pcap.records.size();

        info_msg($sformatf("Done. %0d packet(s) read successfully.", num_pcap_pkts));

        // Constrain starting index
        if (start_idx < 0)                   start_idx = 0;
        else if (start_idx >= num_pcap_pkts) start_idx = num_pcap_pkts-1;

        // Default is to send all packets in pcap file; otherwise
        if (num_pkts == 0)                              num_pkts = num_pcap_pkts;
        // Otherwise, constrain number of packets to number described in PCAP file
        else if ((start_idx + num_pkts) > num_pcap_pkts) num_pkts = (num_pcap_pkts - start_idx);

        // Send packets one at a time
        pkt_idx = 0;
        for (int i = start_idx; i < num_pkts; i++) begin

            // Create new packet transaction from next PCAP record
            packet_verif_pkg::packet_raw#(META_T) packet = packet_verif_pkg::packet_raw#(META_T)::create_from_bytes(
                $sformatf("Packet %0d", pkt_idx),
                pcap.records[i].pkt_data
            );

            info_msg($sformatf("Sending packet # %0d (of %0d)...", pkt_idx+1, num_pkts));

            // Send transaction
            _send(packet);

            info_msg($sformatf("Done. Packet # %0d (of %0d) sent.", pkt_idx+1, num_pkts));

            pkt_idx++;
        end
    endtask

endclass : packet_driver
