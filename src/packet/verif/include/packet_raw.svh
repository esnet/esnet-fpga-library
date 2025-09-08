class packet_raw#(parameter type META_T = bit) extends packet#(META_T);

    local static const string __CLASS_NAME = "packet_verif_pkg::packet_raw";

    //===================================
    // Properties
    //===================================
    local rand byte __data [];

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
        input string name = "packet_raw",
        input int len = 64,
        input META_T meta = '0,
        input bit err = 1'b0
    );
        super.new(name, packet_pkg::PROTOCOL_NONE, meta, err);
        this.__data = new[len];
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        __data.delete();
        super.destroy();
    endfunction

    // Copy from reference
    // [[ implements std_verif_pkg::transaction._copy() ]]
    virtual protected function automatic void _copy(input std_verif_pkg::transaction t2);
        packet_raw#(META_T) pkt;
        super._copy(t2);
        if (!$cast(pkt, t2)) begin
            // Impossible to continue; raise fatal exception.
            $fatal(2, "Transaction type mismatch during object copy operation.");
        end
        from_bytes(pkt.to_bytes());
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Construct raw packet from array of bytes
    static function packet_raw#(META_T) create_from_bytes(
            input string name = "packet_raw",
            input byte data[],
            input META_T meta = '0,
            input bit err = 1'b0
        );
        packet_raw#(META_T) new_packet = new(name, data.size(), meta, err);
        new_packet.from_bytes(data);
        return new_packet;
    endfunction

    // Get string representation of packet
    // [[ overrides std_verif_pkg::packet.to_string() ]]
    virtual function automatic string to_string();
        string str = super.to_string();
        str = {str, string_pkg::horiz_line()};
        str = {str, string_pkg::byte_array_to_string(this.__data)};
        str = {str, string_pkg::horiz_line()};
        return str;
    endfunction

    // Get data as byte array
    // [[ implements packet_verif_pkg::packet.to_bytes ]]
    virtual function automatic byte_array_t to_bytes();
        return this.__data;
    endfunction

    // Set from byte array
    // [[ implements packet_verif_pkg::packet.from_bytes ]]
    virtual function automatic void from_bytes(input byte data []);
        this.__data = data;
    endfunction

    // Header
    // [[ implements packet_verif_pkg::packet.header ]]
    virtual function automatic byte_array_t header();
        return {};
    endfunction

    // Payload
    // [[ implements packet_verif_pkg::packet.payload ]]
    virtual function automatic byte_array_t payload();
        return this.__data;
    endfunction

    // Payload protocol
    // [[ implements packet_verif_pkg::packet.payload_protocol ]]
    virtual function automatic protocol_t payload_protocol();
        return packet_pkg::PROTOCOL_NONE;
    endfunction

endclass : packet_raw

