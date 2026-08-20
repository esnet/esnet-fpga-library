// SAR sequencer
// - decomposes sar_frame_transaction objects into sar_segment_transaction objects
// - segment length is configurable via set_seg_len()
// - out_of_order (per-frame property): segments within a frame are emitted in shuffled order
// - interleave: segments from multiple in-flight frames are interleaved
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
    local int __seg_len   = 512;
    local bit __interleave = 0;

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
        this.__seg_len    = 512;
        this.__interleave = 0;
        this.inbox        = null;
        this.outbox       = null;
        // } WORKAROUND-INIT-PROPS
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        super.destroy();
    endfunction

    // Reset sequencer state
    // [[ overrides std_verif_pkg::sequencer._reset() ]]
    virtual protected function automatic void _reset();
        __interleave = 0;
        super._reset();
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

    // When enabled, each frame is generated in its own forked thread so segments
    // from multiple in-flight frames are interleaved on the output.
    function automatic void set_interleave(input bit en);
        __interleave = en;
    endfunction

    function automatic bit get_interleave();
        return __interleave;
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
            if (__interleave)
                _fork_generate(seq);
            else
                _generate(seq);
        end
    endtask

    // Spawns _generate in a detached thread (used when interleave is enabled).
    // Passing seq as an input parameter captures the handle by value so each
    // thread operates on its own copy of the reference.
    local task automatic _fork_generate(input FRAME_T seq);
        fork begin _generate(seq); end join_none
    endtask

    // Decompose frame into segments, optionally shuffle, then enqueue.
    // [[ implements std_verif_pkg::sequencer._generate() ]]
    protected task _generate(input FRAME_T seq);
        int frame_len = seq.data.size();
        int offset    = 0;
        int seg_idx   = 0;
        SEGMENT_T segs[$];

        trace_msg("_generate()");
        debug_msg($sformatf("Decomposing frame buf_id=0x%0x, len=%0d into %0d-byte segments%s.",
            seq.buf_id, frame_len, __seg_len, seq.out_of_order ? " (out-of-order)" : ""));

        while (offset < frame_len) begin
            SEGMENT_T seg;
            int       seg_len;
            bit       last;

            seg_len = frame_len - offset;
            if (seg_len > __seg_len) seg_len = __seg_len;
            last = (offset + seg_len >= frame_len);

            seg = new(
                $sformatf("%s_seg_%0d", seq.get_name(), seg_idx),
                seq.buf_id,
                OFFSET_T'(offset),
                last,
                seg_len
            );
            for (int i = 0; i < seg_len; i++)
                seg.data[i] = seq.data[offset + i];

            segs.push_back(seg);
            offset  += seg_len;
            seg_idx += 1;
        end

        if (seq.out_of_order) begin
            for (int i = segs.size() - 1; i > 0; i--) begin
                int j = int'($urandom_range(0, i));
                SEGMENT_T tmp = segs[i];
                segs[i] = segs[j];
                segs[j] = tmp;
            end
        end

        foreach (segs[i])
            _enqueue(segs[i]);

        segs.delete();
        trace_msg("_generate() Done.");
    endtask

endclass : sar_sequencer
