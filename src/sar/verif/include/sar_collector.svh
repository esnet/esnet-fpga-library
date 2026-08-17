// SAR collector
// - reassembles sar_segment_transaction objects into sar_frame_transaction objects
// - keyed by buf_id; handles in-order and out-of-order segment arrival
// - a frame is complete when the segment with last=1 has arrived and all bytes
//   from offset 0 to total_len-1 have been received
class sar_collector #(
    parameter type BUF_ID_T = bit,
    parameter type OFFSET_T = bit
) extends std_verif_pkg::collector #(
    sar_segment_transaction#(BUF_ID_T, OFFSET_T),
    sar_frame_transaction#(BUF_ID_T)
);

    local static const string __CLASS_NAME = "sar_verif_pkg::sar_collector";

    //===================================
    // Typedefs
    //===================================
    typedef sar_frame_transaction#(BUF_ID_T)             FRAME_T;
    typedef sar_segment_transaction#(BUF_ID_T, OFFSET_T) SEGMENT_T;

    //===================================
    // Properties (per-frame reassembly state, keyed by buf_id)
    //===================================
    local FRAME_T __pending[BUF_ID_T];   // partially assembled frames
    local int     __rcvd_len[BUF_ID_T];  // bytes received so far per frame
    local int     __total_len[BUF_ID_T]; // total frame length (known when last=1 arrives)
    local bit     __got_last[BUF_ID_T];  // whether the last segment has arrived

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="sar_collector");
        super.new(name);
        // WORKAROUND-INIT-PROPS {
        this.inbox     = null;
        this.outbox    = null;
        __pending   = '{};
        __rcvd_len  = '{};
        __total_len = '{};
        __got_last  = '{};
        // } WORKAROUND-INIT-PROPS
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        __pending.delete();
        __rcvd_len.delete();
        __total_len.delete();
        __got_last.delete();
        super.destroy();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Reset collector state
    // [[ overrides std_verif_pkg::collector._reset() ]]
    virtual protected function automatic void _reset();
        __pending.delete();
        __rcvd_len.delete();
        __total_len.delete();
        __got_last.delete();
        super._reset();
    endfunction

    // Accumulate segment into in-progress frame; emit frame when complete
    // [[ implements std_verif_pkg::collector._process() ]]
    protected task _process(input SEGMENT_T seg);
        BUF_ID_T key = seg.buf_id;

        trace_msg("_process()");
        debug_msg($sformatf("Received segment buf_id=0x%0x, offset=%0d, last=%0b, len=%0d.",
            seg.buf_id, seg.offset, seg.last, seg.data.size()));

        // Allocate pending frame entry on first segment for this buf_id
        if (!__pending.exists(key)) begin
            __pending[key]   = new($sformatf("frame_buf%0x", key), key, 0);
            __rcvd_len[key]  = 0;
            __got_last[key]  = 1'b0;
            __total_len[key] = 0;
        end

        // Grow frame data buffer to accommodate this segment if needed
        begin
            int needed = int'(seg.offset) + seg.data.size();
            if (needed > __pending[key].data.size()) begin
                byte tmp[];
                tmp = new[needed](__pending[key].data);
                __pending[key].data = tmp;
            end
        end

        // Copy segment bytes into the frame at the correct offset
        for (int i = 0; i < seg.data.size(); i++)
            __pending[key].data[int'(seg.offset) + i] = seg.data[i];
        __rcvd_len[key] += seg.data.size();

        // Record total length from the last segment's offset + size
        if (seg.last) begin
            __got_last[key]  = 1'b1;
            __total_len[key] = int'(seg.offset) + seg.data.size();
        end

        // Emit complete frame when all bytes and the last flag have been received
        if (__got_last[key] && __rcvd_len[key] == __total_len[key]) begin
            FRAME_T frame = __pending[key];
            // Trim frame data to exact length (may be oversized if pre-allocated)
            if (frame.data.size() != __total_len[key]) begin
                byte tmp[];
                tmp = new[__total_len[key]](frame.data);
                frame.data = tmp;
            end
            debug_msg($sformatf("Frame buf_id=0x%0x complete, len=%0d.", key, frame.data.size()));
            __pending.delete(key);
            __rcvd_len.delete(key);
            __total_len.delete(key);
            __got_last.delete(key);
            _enqueue(frame);
        end

        trace_msg("_process() Done.");
    endtask

endclass : sar_collector
