class packet #(parameter type META_T = bit) extends std_verif_pkg::transaction;

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
    protected META_T _meta;
    protected bit    _err;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name = "packet",
            input protocol_t protocol = packet_pkg::PROTOCOL_NONE,
            input META_T meta = '0,
            input bit err = 1'b0
        );
        super.new(name);
        this.__protocol = protocol;
        this._meta = meta;
        this._err = err;
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

    // Metadata
    function automatic void set_meta(input META_T meta);
        this._meta = meta;
    endfunction

    function automatic META_T get_meta();
        return this._meta;
    endfunction

    // Out-of-band error indication
    function automatic void mark_as_errored();
        this._err = 1'b0;
    endfunction

    function automatic bit is_errored();
        return this._err;
    endfunction

    // Clone
    virtual function automatic packet#(META_T) clone(input string name); endfunction

    // Get string representation of transaction
    // [[ implements std_verif_pkg::transaction.to_string() ]]
    virtual function automatic string to_string();
        string str;
        str = {str, string_pkg::horiz_line()};
        str = {str,
                $sformatf(
                    "Packet '%s' (%s, %0d bytes, err: %0b, meta: 0x%0x):\n",
                    get_name(),
                    packet_pkg::get_protocol_name(protocol()),
                    size(),
                    this.is_errored(),
                    this._meta
                )
              };
        return str;
    endfunction

    // Compare packets
    virtual function automatic bit _compare(input packet#(META_T) b, output string msg);
        if (this.size() != b.size()) begin
            msg = $sformatf("Packet size mismatch. A: %0d bytes, B: %0d bytes.", this.size(), b.size());
            return 0;
        end else if (this.get_meta() != b.get_meta()) begin
            msg = $sformatf("Packet metadata mismatch. A: 0x%0x, B: 0x%0x.", this.get_meta(), b.get_meta());
            return 0;
        end else if (this.is_errored() != b.is_errored()) begin
            msg = $sformatf("Packet error indication mismatch. A: %b, B: %b.", this.is_errored(), b.is_errored());
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

    // Compare packet transactions
    // [[ implements std_verif_pkg::transaction.compare() ]]
    function bit compare(input packet#(META_T) t2, output string msg);
        return this._compare(t2, msg);
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

