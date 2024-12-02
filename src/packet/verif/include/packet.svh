// Base packet transaction class for verification
// - abstract class (can't be instantiated directly)
// - describes interface for 'generic' packet transactions, where methods are to be implemented by subclass
virtual class packet#(parameter type META_T = bit) extends std_verif_pkg::transaction;

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
    // Pure Virtual Methods
    // (must be implemented by derived class)
    //===================================
    pure virtual function automatic byte_array_t to_bytes();
    pure virtual function automatic void         from_bytes(input byte_array_t data);
    pure virtual function automatic byte_array_t header();
    pure virtual function automatic byte_array_t payload();
    pure virtual function automatic protocol_t   payload_protocol();

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

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        super.destroy();
    endfunction

    // Copy from reference
    // [[ implements std_verif_pkg::transaction._copy() ]]
    virtual protected function automatic void _copy(input std_verif_pkg::transaction t2);
        packet#(META_T) pkt;
        if (!$cast(pkt, t2)) begin
            // Impossible to continue; raise fatal exception.
            $fatal(2, $sformatf("Type mismatch while copying '%s' to '%s'", t2.get_name(), this.get_name()));
        end
        this.__set_protocol(pkt.protocol());
        this.set_meta(pkt.get_meta());
        this._err = pkt.is_errored();
    endfunction

    // Duplicate packet
    //  - enhanced version of clone() that includes the upcast to packet type and
    //    allows for transaction renaming
    virtual function automatic packet#(META_T) dup(input string name=get_name());
        packet#(META_T) pkt;
        if (!$cast(pkt, this.clone())) begin
            // Impossible to continue; raise fatal exception.
            $fatal(2, "Dynamic cast failure during object duplication. This should never happen.");
        end
        pkt.set_name(name);
        return pkt;
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Protocol
    function automatic protocol_t protocol();
        return this.__protocol;
    endfunction

    local function automatic void __set_protocol(input protocol_t protocol);
        this.__protocol = protocol;
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
        this._err = 1'b1;
    endfunction

    function automatic bit is_errored();
        return this._err;
    endfunction

    // Get specified byte
    function automatic byte get_byte(input int idx);
        if (idx < this.size()) begin
            byte_array_t __data = this.to_bytes();
            return __data[idx];
        end else begin
            error_msg($sformatf("Attempted to read byte %0d in packet of length %0d bytes.", idx, this.size()));
            return 0;
        end
    endfunction

    // Set specified byte
    function automatic void set_byte(input int idx, input byte data);
        if (idx < this.size()) begin
            byte_array_t __pkt_as_bytes = this.to_bytes();
            __pkt_as_bytes[idx] = data;
            this.from_bytes(__pkt_as_bytes);
        end else error_msg($sformatf("Attempted to write byte %0d in packet of length %0d bytes.", idx, this.size()));
    endfunction

    // Get string representation of transaction
    // [[ implements std_verif_pkg::transaction.to_string() ]]
    virtual function automatic string to_string();
        string str;
        str = {str, string_pkg::horiz_line()};
        str = {str,
                $sformatf(
                    "Packet '%s' (%s, %0d bytes, err: %0b, meta: 0x%0x):\n",
                    get_name(),
                    packet_pkg::get_protocol_name(__protocol),
                    size(),
                    _err,
                    _meta
                )
              };
        return str;
    endfunction

    // Compare packets
    // [[ implements std_verif_pkg::transaction.compare() ]]
    virtual function automatic bit compare(input std_verif_pkg::transaction t2, output string msg);
        packet#(META_T) b;
        // Cast generic transaction as packet type
        if (!$cast(b, t2)) begin
            msg = $sformatf("Transaction type mismatch. Transaction '%s' is not of type %s or has unexpected parameterization.", t2.get_name(), __CLASS_NAME);
            return 0;
        end
        // Compare packets
        if (this.size() !== b.size()) begin
            msg = $sformatf("Packet size mismatch. A: %0d bytes, B: %0d bytes.", this.size(), b.size());
            return 0;
        end else if (this.get_meta() !== b.get_meta()) begin
            msg = $sformatf("Packet metadata mismatch. A: 0x%0x, B: 0x%0x.", this.get_meta(), b.get_meta());
            return 0;
        end else if (this.is_errored() !== b.is_errored()) begin
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

endclass : packet

