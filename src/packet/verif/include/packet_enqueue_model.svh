class packet_enqueue_model #(
    parameter int DATA_BYTE_WID = 8,
    parameter type ADDR_T = bit,
    parameter type META_T = bit
) extends std_verif_pkg::model#(packet#(META_T),packet_descriptor#(ADDR_T,META_T));

    local static const string __CLASS_NAME = "std_verif_pkg::packet_enqueue_model";

    localparam int __ADDR_WID = $bits(ADDR_T);
    localparam int __BUFFER_WORDS = 2**__ADDR_WID;

    local int __MIN_PKT_SIZE;
    local int __MAX_PKT_SIZE;

    local bit[__ADDR_WID:0] __head_ptr;
    local bit[__ADDR_WID:0] __tail_ptr;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name="packet_enqueue_model",
            input int MIN_PKT_SIZE=40,
            input int MAX_PKT_SIZE=16384
        );
        super.new(name);
        this.__MIN_PKT_SIZE = MIN_PKT_SIZE;
        this.__MAX_PKT_SIZE = MAX_PKT_SIZE;
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

    // Reset model state
    // [[ implements std_verif_pkg::model._reset() ]]
    protected function automatic void _reset();
        trace_msg("_reset()");
        this.__head_ptr = 0;
        this.__tail_ptr = 0;
        trace_msg("_reset() Done.");
    endfunction

    // Set tail pointer (simulate read-side operations)
    function automatic void set_tail_ptr(input int tail_ptr);
        this.__tail_ptr = tail_ptr;
    endfunction

    function automatic bit check_oflow(input int pkt_size);
        bit[__ADDR_WID:0] fill = this.__head_ptr - this.__tail_ptr;
        int avail = this.__BUFFER_WORDS - fill;
        int pkt_words = $ceil(pkt_size * 1.0 / DATA_BYTE_WID);
        return avail < pkt_words;
    endfunction

    // Process input transaction
    // [[ implements std_verif_pkg::model._process() ]]
    protected task _process(input packet#(META_T) transaction);
        packet_descriptor#(ADDR_T,META_T) desc;
        trace_msg("_process()");
        desc = __enqueue_packet(transaction);
        if (desc) _enqueue(desc);
        trace_msg("_process() Done.");
    endtask

    local function automatic packet_descriptor#(ADDR_T,META_T) __enqueue_packet(ref packet#(META_T) pkt);
        packet_descriptor#(ADDR_T,META_T) desc = null;
        trace_msg("__enqueue_packet()");
        if (pkt.is_errored()) begin
            debug_msg(
                $sformatf("Failed to enqueue %s. Packet marked as errored.",
                    pkt.get_name()
                )
            );
        end else if (check_oflow(pkt.size())) begin
            debug_msg(
                $sformatf("Failed to enqueue %s. Overflow detected.",
                    pkt.get_name()
                )
            );
        end else if (pkt.size() > this.__MAX_PKT_SIZE) begin
            debug_msg(
                $sformatf("Failed to enqueue %s. Packet length (%0d) exceeds max (%0d).",
                    pkt.get_name(),
                    pkt.size(),
                    this.__MAX_PKT_SIZE
                )
            );
        end else if (pkt.size() < this.__MIN_PKT_SIZE) begin
            debug_msg(
                $sformatf("Failed to enqueue %s. Packet length (%0d) is less than min (%0d).",
                    pkt.get_name(),
                    pkt.size(),
                    this.__MIN_PKT_SIZE
                )
            );
        end else begin
            desc = packet_descriptor#(ADDR_T,META_T)::create_from_packet(pkt, this.__head_ptr);
            this.__head_ptr += pkt.size() % DATA_BYTE_WID == 0 ? pkt.size() / DATA_BYTE_WID : pkt.size() / DATA_BYTE_WID + 1;
        end
        trace_msg("__enqueue_packet() Done.");
        return desc;
    endfunction

endclass : packet_enqueue_model
