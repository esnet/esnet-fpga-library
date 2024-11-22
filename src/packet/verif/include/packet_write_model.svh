class packet_write_model #(
    parameter int DATA_BYTE_WID = 8,
    parameter type ADDR_T = bit,
    parameter type META_T = bit
) extends std_verif_pkg::model#(packet#(META_T),packet_descriptor#(ADDR_T,META_T));

    local static const string __CLASS_NAME = "std_verif_pkg::packet_write_model";

    //===================================
    // Parameters
    //===================================
    localparam int __ADDR_WID = $bits(ADDR_T);
    localparam int __BUFFER_WORDS = 2**__ADDR_WID;

    local int __MIN_PKT_SIZE;
    local int __MAX_PKT_SIZE;
    local bit __DROP_ERRORED;

    local bit[__ADDR_WID:0] __head_ptr;
    local bit[__ADDR_WID:0] __tail_ptr;

    //===================================
    // Properties
    //===================================
    local packet_descriptor#(ADDR_T,META_T) __descriptors[$];

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name="packet_write_model",
            input int MIN_PKT_SIZE=40,
            input int MAX_PKT_SIZE=16384,
            input bit DROP_ERRORED=1'b1
        );
        super.new(name);
        this.__MIN_PKT_SIZE = MIN_PKT_SIZE;
        this.__MAX_PKT_SIZE = MAX_PKT_SIZE;
        this.__DROP_ERRORED = DROP_ERRORED;
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        __descriptors.delete();
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
        // Delete pending descriptors
        __descriptors.delete();
        trace_msg("_reset() Done.");
    endfunction

    // Set up descriptor
    function automatic void add_descriptor(input packet_descriptor#(ADDR_T,META_T) descriptor);
        __descriptors.push_back(descriptor);
    endfunction

    function automatic packet_descriptor#(ADDR_T,META_T) get_next_descriptor ();
        return __descriptors.pop_front();
    endfunction

    function automatic bit is_descriptor_available();
        return (__descriptors.size() > 0);
    endfunction

    function automatic int get_next_descriptor_size();
        if (is_descriptor_available()) return __descriptors[0].get_size();
        else return 0;
    endfunction

    // Process input transaction
    // [[ implements std_verif_pkg::model._process() ]]
    protected task _process(input packet#(META_T) transaction);
        packet_descriptor#(ADDR_T,META_T) descriptor;
        trace_msg("_process()");
        if (__write_packet(transaction, descriptor)) _enqueue(descriptor);
        trace_msg("_process() Done.");
    endtask

    protected function automatic bit __write_packet(input packet#(META_T) packet, output packet_descriptor#(ADDR_T,META_T) descriptor);
        bit __write_ok = 1'b0;
        trace_msg("__write_packet()");
        if (this.__DROP_ERRORED && packet.is_errored()) begin
            debug_msg(
                $sformatf("Failed to write %s. Packet marked as errored.",
                    packet.get_name()
                )
            );
        end else if (packet.size() > this.__MAX_PKT_SIZE) begin
            debug_msg(
                $sformatf("Failed to write %s. Packet length (%0d) exceeds max (%0d).",
                    packet.get_name(),
                    packet.size(),
                    this.__MAX_PKT_SIZE
                )
            );
        end else if (packet.size() < this.__MIN_PKT_SIZE) begin
            debug_msg(
                $sformatf("Failed to write %s. Packet length (%0d) is less than min (%0d).",
                    packet.get_name(),
                    packet.size(),
                    this.__MIN_PKT_SIZE
                )
            );
        end else if (!is_descriptor_available()) begin
            debug_msg(
                $sformatf("Failed to write %s. No descriptor available.",
                    packet.get_name()
                )
            );
        end else if (packet.size() > get_next_descriptor_size()) begin
            debug_msg(
                $sformatf("Failed to write %s. Packet size exceeds descriptor size.",
                    packet.get_name()
                )
            );
        end else begin
            descriptor = get_next_descriptor();
            descriptor.set_size(packet.size());
            descriptor.set_meta(packet.get_meta());
            if (packet.is_errored()) descriptor.mark_as_errored();
            __write_ok = 1'b1;
        end
        trace_msg("__write_packet() Done.");
        return __write_ok;
    endfunction

endclass : packet_write_model
