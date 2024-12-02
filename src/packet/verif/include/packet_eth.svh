class packet_eth#(parameter type META_T = bit) extends packet#(META_T);

    local static const string __CLASS_NAME = "packet_verif_pkg::packet_eth";

    //===================================
    // Properties
    //===================================
    packet_eth_pkg::hdr_t __hdr;
    packet#() __payload;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name = "packet",
            input packet_eth_pkg::hdr_t hdr,
            input packet#() payload
        );
        super.new(name, packet_pkg::PROTOCOL_ETHERNET);
        this.__hdr = hdr;
        this.__payload = payload;
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        __payload.destroy();
        super.destroy();
    endfunction

    // Copy from reference
    // [[ implements std_verif_pkg::transaction._copy() ]]
    virtual protected function automatic void _copy(input std_verif_pkg::transaction t2);
        packet_eth#(META_T) pkt;
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

    // Get string representation of packet
    // [[ overrides std_verif_pkg::packet.to_string() ]]
    virtual function automatic string to_string();
        string str = super.to_string();
        str = {str, string_pkg::horiz_line()};
        str = {str, string_pkg::byte_array_to_string(this.to_bytes())};
        str = {str, string_pkg::horiz_line()};
        return str;
    endfunction

    // Get data as byte array
    // [[ implements packet_verif_pkg::packet.to_bytes ]]
    virtual function automatic byte_array_t to_bytes();
        return {header(), payload()};
    endfunction

    // Set from byte array
    // [[ implements packet_verif_pkg::packet.from_bytes ]]
    virtual function automatic void from_bytes(input byte_array_t data);
        $fatal(1, "Not implemented.");
    endfunction

    // Header
    // [[ implements packet_verif_pkg::packet.header ]]
    virtual function automatic byte_array_t header();
        return {>>byte{this.__hdr}};
    endfunction

    // Payload
    // [[ implements packet_verif_pkg::packet.payload ]]
    virtual function automatic byte_array_t payload();
        return this.__payload.to_bytes();
    endfunction

    // Payload protocol
    // [[ implements packet_verif_pkg::packet.payload_protocol ]]
    virtual function automatic protocol_t payload_protocol();
        return this.__payload.protocol;
    endfunction

endclass
