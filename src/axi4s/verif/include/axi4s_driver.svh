// =============================================================================
//  NOTICE: This computer software was prepared by The Regents of the
//  University of California through Lawrence Berkeley National Laboratory
//  and Jonathan Sewter hereinafter the Contractor, under Contract No.
//  DE-AC02-05CH11231 with the Department of Energy (DOE). All rights in the
//  computer software are reserved by DOE on behalf of the United States
//  Government and the Contractor as provided in the Contract. You are
//  authorized to use this computer software for Governmental purposes but it
//  is not to be released or distributed to the public.
//
//  NEITHER THE GOVERNMENT NOR THE CONTRACTOR MAKES ANY WARRANTY, EXPRESS OR
//  IMPLIED, OR ASSUMES ANY LIABILITY FOR THE USE OF THIS SOFTWARE.
//
//  This notice including this sentence must appear on any copies of this
//  computer software.
// =============================================================================

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
    protected bit _BIGENDIAN;
    protected int _min_pkt_gap;
    protected int _twait;

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
        this._BIGENDIAN = BIGENDIAN;
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

    // Set twait value used by driver (for stalling transmit transactions)
    function automatic void set_twait(input int twait);
        this._twait = twait;
    endfunction

    // Reset driver state
    // [[ implements std_verif_pkg::driver._reset() ]]
    function automatic void _reset();
        // Nothing to do
    endfunction

    // Put (driven) AXI-S interface in idle state
    // [[ implements std_verif_pkg::driver.idle() ]]
    task idle();
        axis_vif.idle_tx();
    endtask

    // Wait for specified number of 'cycles' on the driven interface
    // [[ implements std_verif_pkg::driver._wait() ]]
    task _wait(input int cycles);
        axis_vif._wait(cycles);
    endtask

    // Wait for interface to be ready to accept transactions (after reset/init, for example)
    // [[ implements std_verif_pkg::driver.wait_ready() ]]
    task wait_ready();
        bit timeout;
        axis_vif.wait_ready(timeout, 0);
    endtask

    // Send transaction (represented as raw byte array with associated metadata)
    task send_raw(
            input byte    data[$],
            input TID_T   id=0,
            input TDEST_T dest=0,
            input TUSER_T user=0,
            input int     twait=0
        );
        // Signals
        tdata_t tdata = '1;
        tkeep_t tkeep = 0;
        bit     tlast = 0;
        int byte_idx = 0;
        int word_idx = 0;

        debug_msg($sformatf("send_raw: Sending %0d bytes...", data.size()));
        // Send
        while (data.size() > 0) begin
            tdata[byte_idx] = data.pop_front();
            tkeep[byte_idx] = 1'b1;
            byte_idx++;
            if ((byte_idx == DATA_BYTE_WID) || (data.size() == 0)) begin
                if (_BIGENDIAN) begin
                    tdata = {<<byte{tdata}};
                    tkeep = {<<{tkeep}};
                end
                if (data.size() == 0) tlast = 1'b1;
                trace_msg($sformatf("send_raw: Sending word %0d.", word_idx));
                axis_vif.send(tdata, tkeep, tlast, id, dest, user, twait);
                tdata = '1;
                tkeep = 0;
                byte_idx = 0;
                word_idx++;
            end
        end
        debug_msg("send_raw: Done.");
        idle();
        _wait(this._min_pkt_gap);
    endtask

    // Send AXI-S transaction on AXI-S bus
    // [[ implements std_verif_pkg::driver._send() ]]
    task _send(
            input axi4s_transaction#(TID_T, TDEST_T, TUSER_T) transaction
        );

        debug_msg($sformatf("Sending:\n%s", transaction.to_string()));

        // Send transaction
        send_raw(transaction.get_packet().to_bytes(), transaction.tid, transaction.tdest, transaction.tuser, _twait);

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
        pcap_pkg::pcap_hdr_t    pcap_hdr;
        pcap_pkg::pcaprec_hdr_t pcap_record_hdr[$];
        byte pkt_data[$][$];
        int num_pcap_pkts;
        int pkt_idx;

        info_msg($sformatf("Reading packets from PCAP file %s for TID %d.", pcap_filename, id));

        // Read packet data from PCAP file
        pcap_pkg::read_pcap(pcap_filename, pcap_hdr, pcap_record_hdr, pkt_data);

        // Get number of packets described in PCAP
        num_pcap_pkts = pcap_record_hdr.size();

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

            // Create new packet transaction from next PCAP record
            packet_verif_pkg::packet_raw packet = packet_verif_pkg::packet_raw::create_from_bytes(
                $sformatf("Packet %0d", pkt_idx),
                pkt_data[i]
            );

            // Generate new AXI-S transaction
            axi4s_transaction#(TID_T, TDEST_T, TUSER_T) transaction = new(
                packet.get_name(),
                packet,
                id,
                dest,
                user
            );

            info_msg($sformatf("TID %d: Sending packet # %0d (of %0d)...", id, pkt_idx+1, num_pkts));

            // Send transaction
            _send(transaction);

            info_msg($sformatf("TID %d: Done. Packet # %0d (of %0d) sent.", id, pkt_idx+1, num_pkts));

            pkt_idx++;
        end
    endtask

endclass : axi4s_driver
