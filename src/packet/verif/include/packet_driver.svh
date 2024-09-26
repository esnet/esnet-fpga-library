virtual class packet_driver#(
    parameter type META_T = bit
) extends std_verif_pkg::driver#(packet#(META_T));

    local static const string __CLASS_NAME = "packet_verif_pkg::packet_driver";

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="packet_driver");
        super.new(name);
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Send packet transaction
    // [[ implements std_verif_pkg::driver._send() ]]
    protected task _send(
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

    //===================================
    // Virtual Methods
    // (to be implemented by derived class)
    //===================================
    virtual task send_raw(input byte data[], input META_T meta = '0, input bit err = 1'b0); endtask

endclass : packet_driver
