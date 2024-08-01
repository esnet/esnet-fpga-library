class packet_descriptor #(parameter type ADDR_T = bit, parameter type META_T = bit) extends std_verif_pkg::transaction;

    local static const string __CLASS_NAME = "packet_verif_pkg::packet_descriptor";

    //===================================
    // Properties
    //===================================
    protected rand META_T _meta;
    protected rand ADDR_T _addr;
    protected rand int _size;

    local int __MIN_SIZE = 40;
    local int __MAX_SIZE = 16384;

    constraint c_pkt_size { _size >= __MIN_SIZE; _size <= __MAX_SIZE; }

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name = "packet_descriptor",
            input ADDR_T addr = '0,
            input int    size =  0,
            input META_T meta = '0
        );
        super.new(name);
        this._addr = addr;
        this._size = size;
        this._meta = meta;
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Address
    function automatic ADDR_T get_addr();
        return this._addr;
    endfunction

    function automatic void set_addr(input ADDR_T addr);
        this._addr = addr;
    endfunction

    // Size
    function automatic int get_size();
        return this._size;
    endfunction

    function automatic void set_size(input int size);
        this._size = size;
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

    // Metadata
    function automatic void set_meta(input META_T meta);
        this._meta = meta;
    endfunction

    function automatic META_T get_meta();
        return this._meta;
    endfunction

    function automatic packet_descriptor#(ADDR_T,META_T) clone(input string name);
        packet_descriptor#(ADDR_T,META_T) cloned_packet_descriptor = new(name, this.get_addr(), this.get_size(), this.get_meta());
        cloned_packet_descriptor.set_min_size(this.__MIN_SIZE);
        cloned_packet_descriptor.set_max_size(this.__MAX_SIZE);
        return cloned_packet_descriptor;
    endfunction

    // Get string representation of packet descriptor
    // [[ implements std_verif_pkg::transaction.to_string() ]]
    virtual function automatic string to_string();
        string str;
        str = {str, string_pkg::horiz_line()};
        str = {str,
                $sformatf(
                    "Packet descriptor '%s' (addr: 0x%0x, %0d bytes, meta: 0x%0x)",
                    get_name(),
                    get_addr(),
                    get_size(),
                    get_meta()
                )
              };
        return str;
    endfunction

    // Compare packet descriptors
    virtual function automatic bit _compare(input packet_descriptor#(ADDR_T,META_T) b, output string msg);
        if (this.get_addr() !== b.get_addr()) begin
            msg = $sformatf("Packet descriptor address mismatch. A: 0x%0x, B: 0x0%0x.", this.get_addr(), b.get_addr());
            return 0;
        end else if (this.get_size() !== b.get_size()) begin
            msg = $sformatf("Packet descriptor size mismatch. A: %0d bytes, B: %0d bytes.", this.get_size(), b.get_size());
            return 0;
        end else if (this.get_meta() !== b.get_meta()) begin
            msg = $sformatf("Packet descriptor metadata mismatch. A: 0x%0x, B: 0x%0x.", this.get_meta(), b.get_meta());
            return 0;
        end
        msg = "Packet descriptors match.";
        return 1;
    endfunction

    // Compare packet descriptors
    // [[ implements std_verif_pkg::transaction.compare() ]]
    virtual function automatic bit compare(input packet_descriptor#(ADDR_T,META_T) t2, output string msg);
        return this._compare(t2, msg);
    endfunction

endclass : packet_descriptor

