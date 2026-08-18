// SAR segment monitor
// - recovers sar_segment_transaction objects from packets on a transport interface
// - unpacks segment metadata (buf_id, offset, last) from packet meta field:
//     meta[BUF_ID_WID+OFFSET_WID : OFFSET_WID+1] = buf_id
//     meta[OFFSET_WID : 1]                        = offset
//     meta[0]                                      = last
// - delegates transport to an injected packet_monitor (assign pkt_monitor before run())
class sar_segment_monitor #(
    parameter type BUF_ID_T = bit,
    parameter type OFFSET_T = bit
) extends std_verif_pkg::monitor #(
    sar_segment_transaction#(BUF_ID_T, OFFSET_T)
);

    local static const string __CLASS_NAME = "sar_verif_pkg::sar_segment_monitor";

    //===================================
    // Parameters
    //===================================
    localparam int BUF_ID_WID   = $bits(BUF_ID_T);
    localparam int OFFSET_WID   = $bits(OFFSET_T);
    localparam int SEG_META_WID = BUF_ID_WID + OFFSET_WID + 1;

    //===================================
    // Typedefs
    //===================================
    typedef logic [SEG_META_WID-1:0]                      SEG_META_T;
    typedef sar_segment_transaction#(BUF_ID_T, OFFSET_T)  SEGMENT_T;
    typedef packet#(SEG_META_T)                            SEG_PKT_BASE_T;

    //===================================
    // Properties
    //===================================
    // Injected transport monitor — assign before run()
    packet_monitor#(SEG_META_T) pkt_monitor;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="sar_segment_monitor");
        super.new(name);
        // WORKAROUND-INIT-PROPS {
        this.pkt_monitor = null;
        this.outbox      = null;
        // } WORKAROUND-INIT-PROPS
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        pkt_monitor = null;
        super.destroy();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Put transport interface in idle state
    // [[ implements std_verif_pkg::component._idle() ]]
    virtual protected task _idle();
        pkt_monitor.idle();
    endtask

    // Monitor run loop — drives _receive→outbox cycle.
    // [[ overrides std_verif_pkg::monitor._run() ]]
    // WORKAROUND: xsim fails to access private base-class fields (__cnt) of
    // parameterized monitor specialisations when _run() executes in a forked thread.
    // Overriding here keeps all field accesses in sar_segment_monitor scope.
    protected task _run();
        SEGMENT_T transaction;
        forever begin
            _receive(transaction);
            outbox.put(transaction);
        end
    endtask

    // Receive a packet from the transport and reconstruct a segment transaction
    // [[ implements std_verif_pkg::monitor._receive() ]]
    protected task _receive(output SEGMENT_T transaction);
        SEG_PKT_BASE_T pkt;
        SEG_META_T     meta;
        BUF_ID_T       buf_id;
        OFFSET_T       offset;
        bit            last;
        byte           data[];

        trace_msg("_receive()");

        pkt_monitor.receive(pkt);

        // Unpack meta: bits packed as {buf_id, offset, last} MSB-first
        meta   = pkt.get_meta();
        buf_id = BUF_ID_T'(meta[SEG_META_WID-1 : OFFSET_WID+1]);
        offset = OFFSET_T'(meta[OFFSET_WID : 1]);
        last   = meta[0];

        data = pkt.to_bytes();

        transaction = new(
            $sformatf("seg_rx_b%0x_o%0d", buf_id, int'(offset)),
            buf_id,
            offset,
            last,
            data.size()
        );
        for (int i = 0; i < data.size(); i++)
            transaction.data[i] = data[i];

        debug_msg($sformatf("Received segment buf_id=0x%0x, offset=%0d, last=%0b, len=%0d.",
            buf_id, offset, last, data.size()));

        trace_msg("_receive() Done.");
    endtask

endclass : sar_segment_monitor
