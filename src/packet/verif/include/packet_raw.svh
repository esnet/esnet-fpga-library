class packet_raw extends packet;

    local static const string __CLASS_NAME = "packet_verif_pkg::packet_raw";

    //===================================
    // Properties
    //===================================
    local const int __len;
    local rand byte __data [];

    constraint c_length { __data.size() == __len; }

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
        input string name = "packet_raw",
        input int len = 64
    );
        super.new(name, packet_pkg::PROTOCOL_NONE);
        this.__len = len;
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Construct raw packet from array of bytes
    static function packet_raw create_from_bytes(
        input string name = "packet_raw",
        input byte data[]
    );
        packet_raw new_packet = new(name, data.size());
        new_packet.set_from_bytes(data);
        return new_packet;
    endfunction

    function automatic packet_raw clone(input string name);
        packet_raw cloned_packet = packet_raw::create_from_bytes(name, this.to_bytes);
        return cloned_packet;
    endfunction

    // Get string representation of packet
    // [[ overrides std_verif_pkg::transaction.to_string() extended class ]]
    function string to_string();
        string str = super.to_string();
        str = {str, std_string_pkg::horiz_line()};
        str = {str, std_string_pkg::byte_array_to_string(this.__data)};
        str = {str, std_string_pkg::horiz_line()};
        return str;
    endfunction

    //===================================
    // Virtual Methods
    // (to be implemented by derived class)
    //===================================
    // Get data as byte array
    function automatic byte_array_t to_bytes();
        return this.__data;
    endfunction

    // Set from byte array
    function automatic void set_from_bytes(input byte data[]);
        this.__data = data;
    endfunction

    // Get specified byte
    function automatic byte get_byte(input int idx);
        if (idx < this.size()) return this.__data[idx];
        else begin
            error_msg($sformatf("Attempted to read byte %0d in packet of length %0d bytes.", idx, this.size()));
            return 0;
        end
    endfunction

    // Set specified byte
    function automatic void set_byte(input int idx, input byte data);
        if (idx < this.size()) this.__data[idx] = data;
        else error_msg($sformatf("Attempted to write byte %0d in packet of length %0d bytes.", idx, this.size()));
    endfunction

    // Header
    function automatic byte_array_t header();
        return {};
    endfunction

    // Payload
    function automatic byte_array_t payload();
        return this.__data;
    endfunction

    // Payload protocol
    function automatic protocol_t payload_protocol();
        return packet_pkg::PROTOCOL_NONE;
    endfunction

endclass : packet_raw

