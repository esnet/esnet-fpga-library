// Per-frame reassembly context — stored as a queue inside sar_collector.
// Defined at package scope so its type is non-parameterized; this avoids
// a Vivado xelab code-generation SIGSEGV that occurs when associative
// arrays (including associative arrays of dynamic arrays) appear inside
// a parameterized class body.
class sar_collector_ctx;
    int    buf_id_key;
    byte   data[];
    int    rcvd_len;
    int    total_len;
    bit    got_last;

    function new(input int key);
        this.buf_id_key = key;
        this.data       = new[0];
        this.rcvd_len   = 0;
        this.total_len  = 0;
        this.got_last   = 1'b0;
    endfunction
endclass : sar_collector_ctx

// SAR collector
// - reassembles sar_segment_transaction objects into sar_frame_transaction objects
// - keyed by buf_id (as int); handles in-order and out-of-order segment arrival
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
    // Properties
    // Queue of non-parameterized context objects avoids the xelab SIGSEGV
    // triggered by associative arrays inside parameterized class bodies.
    //===================================
    local sar_collector_ctx __pending[$];

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="sar_collector");
        super.new(name);
        // WORKAROUND-INIT-PROPS {
        this.inbox    = null;
        this.outbox   = null;
        __pending   = '{};
        // } WORKAROUND-INIT-PROPS
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        __pending.delete();
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
        super._reset();
    endfunction

    // Find (or create) the context entry for the given int key
    local function automatic sar_collector_ctx __get_ctx(input int key);
        foreach (__pending[i]) begin
            if (__pending[i].buf_id_key == key) return __pending[i];
        end
        begin
            sar_collector_ctx ctx = new(key);
            __pending.push_back(ctx);
            return ctx;
        end
    endfunction

    // Remove context entry for the given key
    local function automatic void __del_ctx(input int key);
        for (int i = 0; i < __pending.size(); i++) begin
            if (__pending[i].buf_id_key == key) begin
                __pending.delete(i);
                return;
            end
        end
    endfunction

    // Collector run loop — drives inbox→_process→_enqueue cycle.
    // [[ overrides std_verif_pkg::collector._run() ]]
    // WORKAROUND: xsim fails to access private base-class fields (__cnt_in, __cnt_out)
    // of parameterized collector specialisations when _run() executes in a forked thread.
    // Overriding _run() here keeps all field accesses in sar_collector itself.
    protected task _run();
        SEGMENT_T transaction;
        forever begin
            inbox.get(transaction);
            _process(transaction);
        end
    endtask

    // Accumulate segment into in-progress frame; emit frame when complete
    // [[ implements std_verif_pkg::collector._process() ]]
    protected task _process(input SEGMENT_T transaction);
        int key = int'(transaction.buf_id);
        sar_collector_ctx ctx;

        trace_msg("_process()");
        debug_msg($sformatf("Received segment buf_id=0x%0x, offset=%0d, last=%0b, len=%0d.",
            transaction.buf_id, transaction.offset, transaction.last, transaction.data.size()));

        ctx = __get_ctx(key);

        // Grow byte buffer to accommodate this segment if needed
        begin
            int needed = int'(transaction.offset) + transaction.data.size();
            if (needed > ctx.data.size()) begin
                byte tmp[];
                tmp = new[needed](ctx.data);
                ctx.data = tmp;
            end
        end

        // Copy segment bytes into buffer at the correct offset
        for (int i = 0; i < transaction.data.size(); i++)
            ctx.data[int'(transaction.offset) + i] = transaction.data[i];
        ctx.rcvd_len += transaction.data.size();

        // Record total length from the last segment's offset + size
        if (transaction.last) begin
            ctx.got_last  = 1'b1;
            ctx.total_len = int'(transaction.offset) + transaction.data.size();
        end

        // Emit complete frame when all bytes and the last flag have been received
        if (ctx.got_last && ctx.rcvd_len == ctx.total_len) begin
            FRAME_T frame;
            frame = new($sformatf("frame_buf%0x", key), BUF_ID_T'(key), ctx.total_len);
            for (int i = 0; i < ctx.total_len; i++)
                frame.data[i] = ctx.data[i];
            debug_msg($sformatf("Frame buf_id=0x%0x complete, len=%0d.", key, frame.data.size()));
            __del_ctx(key);
            _enqueue(frame);
        end

        trace_msg("_process() Done.");
    endtask

endclass : sar_collector
