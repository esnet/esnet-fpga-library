class packet_eth extends packet;

    local static const string __CLASS_NAME = "packet_verif_pkg::packet_eth";

    //===================================
    // Properties
    //===================================
    packet_eth_pkg::hdr_t __hdr;
    packet __payload;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name = "packet",
            input packet_eth_pkg::hdr_t hdr,
            input packet payload
        );
        super.new(name, packet_pkg::PROTOCOL_ETHERNET);
        this.__hdr = hdr;
        this.__payload = payload;
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Get string representation of packet
    function automatic string to_string();
        string str = super.to_string();
        str = {str, std_string_pkg::horiz_line()};
        str = {str, std_string_pkg::byte_array_to_string(this.to_bytes())};
        str = {str, std_string_pkg::horiz_line()};
        return str;
    endfunction

    function automatic byte_array_t to_bytes();
        return {header(), payload()};
    endfunction

    function automatic byte_array_t header();
        return {>>byte{this.__hdr}};
    endfunction

    function automatic byte_array_t payload();
        return this.__payload.to_bytes();
    endfunction

    function automatic protocol_t payload_protocol();
        return this.__payload.protocol();
    endfunction

endclass
