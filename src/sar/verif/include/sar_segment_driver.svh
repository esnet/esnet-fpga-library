// SAR segment driver
// - translates sar_segment_transaction objects into packets on a transport interface
// - packs segment metadata (buf_id, offset, last, packet metadata) into packet meta field:
//   meta = {buf_id, offset, last, packet (opaque) metadata}
// - delegates transport to an injected packet_driver (assign pkt_driver before run())
class sar_segment_driver #(
    parameter type BUF_ID_T = bit,
    parameter type OFFSET_T = bit,
    parameter type META_T = bit
) extends std_verif_pkg::driver #(
    sar_segment_transaction#(BUF_ID_T, OFFSET_T)
);

    local static const string __CLASS_NAME = "sar_verif_pkg::sar_segment_driver";

    //===================================
    // Parameters
    //===================================
    localparam int BUF_ID_WID   = $bits(BUF_ID_T);
    localparam int OFFSET_WID   = $bits(OFFSET_T);
    localparam int META_WID     = $bits(META_T);

    typedef struct packed {
        logic [BUF_ID_WID-1:0] buf_id;
        logic [OFFSET_WID-1:0] offset;
        logic                  last;
        logic [META_WID-1:0]   opaque;
    } meta_t;
    localparam int SEG_META_WID = $bits(meta_t);

    //===================================
    // Typedefs
    //===================================
    typedef logic [SEG_META_WID-1:0]                      SEG_META_T;
    typedef sar_segment_transaction#(BUF_ID_T, OFFSET_T)  SEGMENT_T;
    typedef packet_raw#(SEG_META_T)                       SEG_PKT_T;

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

    // Reset driver state
    // [[ overrides std_verif_pkg::driver._reset() ]]
    virtual protected function automatic void _reset();
        pkt_driver.reset();
        super._reset();
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
        meta_t meta;
        SEG_PKT_T  pkt;

        trace_msg("_send()");
        debug_msg($sformatf("Sending segment buf_id=0x%0x, offset=%0d, last=%0b, len=%0d.",
            transaction.buf_id, transaction.offset, transaction.last, transaction.data.size()));

        // Pack {buf_id, offset, last} MSB-first into meta
        meta.buf_id = transaction.buf_id;
        meta.offset = transaction.offset;
        meta.last   = transaction.last;
        meta.opaque = '0;

        pkt = SEG_PKT_T::create_from_bytes(
            $sformatf("%s_pkt", transaction.get_name()),
            transaction.data,
            SEG_META_T'(meta)
        );

        pkt_driver.send(pkt);

        trace_msg("_send() Done.");
    endtask

endclass : sar_segment_driver
