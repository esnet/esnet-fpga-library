class packet extends std_verif_pkg::base;

    local static const string __CLASS_NAME = "packet_verif_pkg::packet";

    //===================================
    // Typedefs
    //===================================
    typedef packet_pkg::protocol_t protocol_t;
    typedef byte byte_array_t [];

    //===================================
    // Properties
    //===================================
    local protocol_t __protocol;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name = "packet",
            input protocol_t protocol = packet_pkg::PROTOCOL_NONE
        );
        super.new(name);
        this.__protocol = protocol;
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Packet type
    function automatic protocol_t protocol();
        return this.__protocol;
    endfunction

    // Size
    function automatic int size();
        return this.to_bytes().size();
    endfunction

    // Clone
    virtual function automatic packet clone(input string name); endfunction

    // Get string representation of packet
    virtual function string to_string();
        string str;
        str = {str, string_pkg::horiz_line()};
        str = {str,
                $sformatf(
                    "Packet '%s' (%s, %0d bytes):\n",
                    get_name(),
                    packet_pkg::get_protocol_name(protocol()),
                    size()
                )
              };
        return str;
    endfunction

    // Compare packets
    function bit compare(input packet b, output string msg);
        if (this.size() != b.size()) begin
            msg = $sformatf("Packet size mismatch. A: %0d bytes, B: %0d bytes.", this.size(), b.size());
            return 0;
        end else begin
            byte a_data [] = this.to_bytes();
            byte b_data [] = b.to_bytes();
            for (int i = 0; i < this.size(); i++) begin
                if (a_data[i] != b_data[i]) begin
                    msg = $sformatf(
                        "Packet data mismatch at byte %0d. A[%0d]: %2x, B[%0d]: %2x",
                        i, i, a_data[i], i, b_data[i]
                    );
                    return 0;
                end
            end
        end
        msg = "Packets match.";
        return 1;
    endfunction

    //===================================
    // Virtual Methods
    // (to be implemented by derived class)
    //===================================
    virtual function automatic byte_array_t to_bytes(); endfunction
    virtual function automatic byte_array_t header(); endfunction
    virtual function automatic byte_array_t payload(); endfunction
    virtual function automatic protocol_t   payload_protocol(); endfunction

endclass : packet

