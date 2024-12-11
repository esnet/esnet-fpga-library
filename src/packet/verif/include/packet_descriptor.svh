class packet_descriptor #(parameter type ADDR_T = bit, parameter type META_T = bit) extends std_verif_pkg::transaction;

    local static const string __CLASS_NAME = "packet_verif_pkg::packet_descriptor";

    //===================================
    // Properties
    //===================================
    rand META_T meta;
    rand ADDR_T addr;
    rand int size;
    rand bit err;

    local int __MIN_SIZE = 40;
    local int __MAX_SIZE = 16384;

    constraint c_pkt_size { size >= __MIN_SIZE; size <= __MAX_SIZE; }

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name = "packet_descriptor",
            input ADDR_T addr = '0,
            input int    size =  0,
            input META_T meta = '0,
            input bit    err = 1'b0
        );
        super.new(name);
        this.addr = addr;
        this.size = size;
        this.err = err;
        this.meta = meta;
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        super.destroy();
    endfunction

    // Copy
    // [[ implements std_verif_pkg::transaction._copy() ]]
    virtual protected function automatic void _copy(input std_verif_pkg::transaction t2);
        packet_descriptor#(ADDR_T,META_T) desc;
        super._copy(t2);
        if (!$cast(desc, t2)) begin
            // Impossible to continue; raise fatal exception.
            $fatal(2, "Transaction type mismatch during object copy operation.");
        end
        this.addr = desc.addr;
        this.size = desc.size;
        this.err = desc.err;
        this.meta = desc.meta;
    endfunction

    // Clone
    // [[ implements std_verif_pkg::transaction.clone() ]]
    virtual function automatic std_verif_pkg::transaction clone();
        // Use explicit constructor here instead of copy constructor to avoid
        // apparent Vivado simulator bugs (as of Vivado v2024.2)
        packet_descriptor#(ADDR_T,META_T) desc = new(
            get_name(),
            addr,
            size,
            meta,
            err
        );
        return desc;
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    function automatic void set_max_size(input int MAX_SIZE);
        this.__MAX_SIZE = MAX_SIZE;
    endfunction

    function automatic int get_max_size();
        return this.__MAX_SIZE;
    endfunction

    function automatic void set_min_size(input int MIN_SIZE);
        this.__MIN_SIZE = MIN_SIZE;
    endfunction

    function automatic int get_min_size();
        return this.__MIN_SIZE;
    endfunction

    static function automatic packet_descriptor#(ADDR_T,META_T) create_from_packet(ref packet#(META_T) pkt, input ADDR_T addr);
        packet_descriptor#(ADDR_T,META_T) desc = new(pkt.get_name(), addr, pkt.size(), pkt.get_meta(), pkt.is_errored());
        return desc;
    endfunction

    // Duplicate descriptor
    function automatic packet_descriptor#(ADDR_T,META_T) dup(input string name=get_name());
        packet_descriptor#(ADDR_T,META_T) desc;
        if (!$cast(desc, this.clone())) begin
            // Impossible to continue; raise fatal exception.
            $fatal(2, "Dynamic cast failure during object duplication. This should never happen.");
        end
        desc.set_name(name);
        return desc;
    endfunction

    // Get string representation of packet descriptor
    // [[ implements std_verif_pkg::transaction.to_string() ]]
    virtual function automatic string to_string();
        string str;
        str = {str, string_pkg::horiz_line()};
        str = {str,
                $sformatf(
                    "Packet descriptor '%s' (addr: 0x%0x, %0d bytes, err: %0b, meta: 0x%0x)",
                    get_name(),
                    addr,
                    size,
                    err,
                    meta
                )
              };
        return str;
    endfunction

    // Compare packet descriptors
    // [[ implements std_verif_pkg::transaction.compare() ]]
    virtual function automatic bit compare(input std_verif_pkg::transaction t2, output string msg);
        packet_descriptor#(ADDR_T,META_T) b;
        // Cast generic transaction as packet_descriptor type
        if (!$cast(b, t2)) begin
            msg = $sformatf("Transaction type mismatch. Transaction '%s' is not of type %s or has unexpected parameterization.", t2.get_name(), __CLASS_NAME);
            return 0;
        end
        // Compare packet descriptors
        if (this.addr !== b.addr) begin
            msg = $sformatf("Packet descriptor address mismatch. A: 0x%0x, B: 0x0%0x.", this.addr, b.addr);
            return 0;
        end else if (this.size !== b.size) begin
            msg = $sformatf("Packet descriptor size mismatch. A: %0d bytes, B: %0d bytes.", this.size, b.size);
            return 0;
        end else if (this.meta !== b.meta) begin
            msg = $sformatf("Packet descriptor metadata mismatch. A: 0x%0x, B: 0x%0x.", this.meta, b.meta);
            return 0;
        end else if (this.err != b.err) begin
            msg = $sformatf("Packet descriptor error mismatch. A: %0b, B: %0b.", this.err, b.err);
            return 0;
        end
        msg = "Packet descriptors match.";
        return 1;
    endfunction

endclass : packet_descriptor

