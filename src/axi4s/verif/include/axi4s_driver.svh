class axi4s_driver #(
    parameter int DATA_BYTE_WID = 8,
    parameter type TID_T = bit,
    parameter type TDEST_T = bit,
    parameter type TUSER_T = bit
) extends std_verif_pkg::driver#(axi4s_transaction#(TID_T, TDEST_T, TUSER_T));

    local static const string __CLASS_NAME = "axi4s_verif_pkg::axi4s_driver";

    //===================================
    // Properties
    //===================================
    local bit __BIGENDIAN;
    local int __min_pkt_gap = 0;
    local int __twait = 0;

    //===================================
    // Interfaces
    //===================================
    virtual axi4s_intf #(
        .DATA_BYTE_WID(DATA_BYTE_WID),
        .TID_T(TID_T),
        .TDEST_T(TDEST_T),
        .TUSER_T(TUSER_T)
    ) axis_vif;

    //===================================
    // Typedefs
    //===================================
    typedef bit [DATA_BYTE_WID-1:0][7:0] tdata_t;
    typedef bit [DATA_BYTE_WID-1:0]      tkeep_t;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="axi4s_driver", input bit BIGENDIAN=1);
        super.new(name);
        this.__BIGENDIAN = BIGENDIAN;
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        axis_vif = null;
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

    // Set twait value used by driver (for stalling transmit transactions)
    function automatic void set_twait(input int twait);
        this.__twait = twait;
    endfunction

    // Reset driver
    // [[ overrides std_verif_pkg::driver._reset() ]]
    virtual protected function automatic void _reset();
        super._reset();
        this.set_twait(0);
        this.set_min_gap(0);
    endfunction

    // Quiesce AXI-S interface
    // [[ implements std_verif_pkg::component._idle() ]]
    virtual protected task _idle();
        super._idle();
        axis_vif.idle_tx();
    endtask

    // Send transaction (represented as raw byte array with associated metadata)
    protected task _send_raw(
            input byte    data[],
            input TID_T   id=0,
            input TDEST_T dest=0,
            input TUSER_T user=0
        );
        byte __data[$] = data;
        // Signals
        tdata_t tdata = '1;
        tkeep_t tkeep = 0;
        bit     tlast = 0;
        int byte_idx = 0;
        int word_idx = 0;

        debug_msg($sformatf("send_raw: Sending %0d bytes...", data.size()));
        // Send
        while (__data.size() > 0) begin
            tdata[byte_idx] = __data.pop_front();
            tkeep[byte_idx] = 1'b1;
            byte_idx++;
            if ((byte_idx == DATA_BYTE_WID) || (__data.size() == 0)) begin
                if (this.__BIGENDIAN) begin
                    tdata = {<<byte{tdata}};
                    tkeep = {<<{tkeep}};
                end
                if (__data.size() == 0) tlast = 1'b1;
                trace_msg($sformatf("send_raw: Sending word %0d.", word_idx));
                axis_vif.send(tdata, tkeep, tlast, id, dest, user, this.__twait);
                tdata = '1;
                tkeep = 0;
                byte_idx = 0;
                word_idx++;
            end
        end
        debug_msg("send_raw: Done.");
        axis_vif.idle_tx();
        axis_vif._wait(this.__min_pkt_gap);
    endtask

    // Send packet
    // [[ implements std_verif_pkg::driver._send() ]]
    protected task _send(input axi4s_transaction#(TID_T, TDEST_T, TUSER_T) transaction);

        debug_msg($sformatf("Sending:\n%s", transaction.to_string()));

        // Send packet transaction
        _send_raw(transaction.to_bytes(), transaction.get_tid(), transaction.get_tdest(), transaction.get_tuser());

        debug_msg("Done.");
    endtask

    // Send packets from PCAP file as AXI-S transactions on AXI-S bus
    task send_from_pcap(
            input string pcap_filename,
            input int num_pkts=0,
            input int start_idx=0,
            input int twait=0,
            input TID_T id=0,
            input TDEST_T dest=0,
            input TUSER_T user=0
        );
        // Signals
        pcap_pkg::pcap_t pcap;
        byte pkt_data[$][$];
        int num_pcap_pkts;
        int pkt_idx;

        info_msg($sformatf("Reading packets from PCAP file %s for TID %d.", pcap_filename, id));

        // Read packet data from PCAP file
        pcap = pcap_pkg::read_pcap(pcap_filename);

        // Get number of packets described in PCAP
        num_pcap_pkts = pcap.records.size();

        info_msg($sformatf("Done. %0d packet(s) read successfully for TID %d.", num_pcap_pkts, id));

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

            // Generate new AXI-S transaction from next PCAP record
            axi4s_transaction#(TID_T, TDEST_T, TUSER_T) transaction =
                axi4s_transaction#(TID_T, TDEST_T, TUSER_T)::create_from_bytes(
                    $sformatf("Packet %0d", pkt_idx),
                    pcap.records[i].pkt_data,
                    id,
                    dest,
                    user
                );

            info_msg($sformatf("TID %d: Sending packet # %0d (of %0d)...", id, pkt_idx+1, num_pkts));

            // Send transaction
            send(transaction);

            info_msg($sformatf("TID %d: Done. Packet # %0d (of %0d) sent.", id, pkt_idx+1, num_pkts));

            pkt_idx++;
        end
    endtask
  
endclass : axi4s_driver
