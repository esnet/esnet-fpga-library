class packet_transaction extends std_verif_pkg::transaction;

    local static const string __CLASS_NAME = "packet_verif_pkg::packet_transaction";

    //===================================
    // Typedefs
    //===================================
    typedef byte byte_array_t [];

    //===================================
    // Properties
    //===================================
    local const packet __packet;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name="packet_transaction",
            input packet packet
        );
        super.new(name);
        this.__packet = packet;
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Return packet
    function automatic packet get_packet();
        return this.__packet;
    endfunction

    // Return packet data as array of bytes
    function automatic byte_array_t to_bytes();
        return get_packet().to_bytes();
    endfunction

    // Get size of packet in bytes
    function automatic int size();
        return get_packet().size();
    endfunction

    // Get string representation of transaction
    // [[ implements std_verif_pkg::transaction.to_string() ]]
    function automatic string to_string();
        string str;
        str = $sformatf("Packet transaction '%s' (%0d bytes):\n", get_name(), size());
        str = {str, this.__packet.to_string()};
        return str;
    endfunction

    // Compare transaction against another
    // [[ implements std_verif_pkg::transaction.compare() ]]
    function automatic bit compare(input packet_transaction t2, output string msg);
        return this.__packet.compare(t2.get_packet(), msg);
    endfunction

endclass
