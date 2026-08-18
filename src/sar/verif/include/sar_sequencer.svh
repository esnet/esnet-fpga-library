// SAR sequencer
// - decomposes sar_frame_transaction objects into sar_segment_transaction objects
// - segment length is configurable via set_seg_len()
class sar_sequencer #(
    parameter type BUF_ID_T = bit,
    parameter type OFFSET_T = bit
) extends std_verif_pkg::sequencer #(
    sar_frame_transaction#(BUF_ID_T),
    sar_segment_transaction#(BUF_ID_T, OFFSET_T)
);

    local static const string __CLASS_NAME = "sar_verif_pkg::sar_sequencer";

    //===================================
    // Properties
    //===================================
    local int __seg_len = 512;

    //===================================
    // Typedefs
    //===================================
    typedef sar_frame_transaction#(BUF_ID_T)            FRAME_T;
    typedef sar_segment_transaction#(BUF_ID_T, OFFSET_T) SEGMENT_T;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="sar_sequencer");
        super.new(name);
        // WORKAROUND-INIT-PROPS {
        this.__seg_len = 512;
        this.inbox     = null;
        this.outbox    = null;
        // } WORKAROUND-INIT-PROPS
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        super.destroy();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Configure segment length (bytes)
    function automatic void set_seg_len(input int len);
        __seg_len = len;
    endfunction

    function automatic int get_seg_len();
        return __seg_len;
    endfunction

    // Sequencer run loop — drives inbox→_generate→_enqueue cycle.
    // [[ overrides std_verif_pkg::sequencer._run() ]]
    // WORKAROUND: xsim fails to access private base-class fields (__seq_cnt,
    // __transaction_cnt) of parameterized sequencer specialisations when _run()
    // executes in a forked thread. Overriding here keeps all field accesses local.
    protected task _run();
        FRAME_T seq;
        forever begin
            inbox.get(seq);
            _generate(seq);
        end
    endtask

    // Decompose frame into segments
    // [[ implements std_verif_pkg::sequencer._generate() ]]
    protected task _generate(input FRAME_T seq);
        int frame_len = seq.data.size();
        int offset    = 0;

        trace_msg("_generate()");
        debug_msg($sformatf("Decomposing frame buf_id=0x%0x, len=%0d into %0d-byte segments.",
            seq.buf_id, frame_len, __seg_len));

        while (offset < frame_len) begin
            SEGMENT_T seg;
            int       seg_len;
            bit       last;

            seg_len = frame_len - offset;
            if (seg_len > __seg_len) seg_len = __seg_len;
            last = (offset + seg_len >= frame_len);

            seg = new(
                $sformatf("%s_seg_%0d", seq.get_name(), num_transactions()),
                seq.buf_id,
                OFFSET_T'(offset),
                last,
                seg_len
            );
            for (int i = 0; i < seg_len; i++)
                seg.data[i] = seq.data[offset + i];

            _enqueue(seg);
            offset += seg_len;
        end

        trace_msg("_generate() Done.");
    endtask

endclass : sar_sequencer
