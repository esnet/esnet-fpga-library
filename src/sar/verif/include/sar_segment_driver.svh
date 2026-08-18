// SAR segment driver
// - translates sar_segment_transaction objects into packets on a transport interface
// - packs segment metadata (buf_id, offset, last) into packet meta field:
//     meta[BUF_ID_WID+OFFSET_WID : OFFSET_WID+1] = buf_id
//     meta[OFFSET_WID : 1]                        = offset
//     meta[0]                                      = last
// - delegates transport to an injected packet_driver (assign pkt_driver before run())
class sar_segment_driver #(
    parameter type BUF_ID_T = bit,
    parameter type OFFSET_T = bit
) extends std_verif_pkg::driver #(
    sar_segment_transaction#(BUF_ID_T, OFFSET_T)
);

    local static const string __CLASS_NAME = "sar_verif_pkg::sar_segment_driver";

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
    typedef packet_raw#(SEG_META_T)                        SEG_PKT_T;

    //===================================
    // Properties
    //===================================
    // Injected transport driver — assign before run()
    packet_driver#(SEG_META_T) pkt_driver;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="sar_segment_driver");
        super.new(name);
        // WORKAROUND-INIT-PROPS {
        this.pkt_driver = null;
        this.inbox      = null;
        // } WORKAROUND-INIT-PROPS
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        pkt_driver = null;
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
        pkt_driver.idle();
    endtask

    // Driver run loop — drives inbox→_send cycle.
    // [[ overrides std_verif_pkg::driver._run() ]]
    // WORKAROUND: xsim fails to access private base-class fields (__cnt) of
    // parameterized driver specialisations when _run() executes in a forked thread.
    // Overriding here keeps all field accesses in sar_segment_driver scope.
    protected task _run();
        SEGMENT_T transaction;
        forever begin
            inbox.get(transaction);
            _send(transaction);
        end
    endtask

    // Pack segment into a packet and send via the injected transport driver
    // [[ implements std_verif_pkg::driver._send() ]]
    protected task _send(input SEGMENT_T transaction);
        SEG_META_T meta;
        SEG_PKT_T  pkt;

        trace_msg("_send()");
        debug_msg($sformatf("Sending segment buf_id=0x%0x, offset=%0d, last=%0b, len=%0d.",
            transaction.buf_id, transaction.offset, transaction.last, transaction.data.size()));

        // Pack {buf_id, offset, last} MSB-first into meta
        meta = {transaction.buf_id, transaction.offset, transaction.last};

        pkt = SEG_PKT_T::create_from_bytes(
            $sformatf("%s_pkt", transaction.get_name()),
            transaction.data,
            meta
        );

        pkt_driver.send(pkt);

        trace_msg("_send() Done.");
    endtask

endclass : sar_segment_driver
