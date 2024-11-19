class axi4s_transaction #(
    parameter type TID_T = bit,
    parameter type TDEST_T = bit,
    parameter type TUSER_T = bit
) extends packet_verif_pkg::packet_raw#(struct packed {TID_T tid; TDEST_T tdest; TUSER_T tuser;});

    local static const string __CLASS_NAME = "axi4s_verif_pkg::axi4s_transaction";

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name="axi4s_transaction",
            input int len = 64,
            input TID_T tid = '0,
            input TDEST_T tdest = '0,
            input TUSER_T tuser = '0,
            input bit err = 1'b0
        );
        super.new(name, len, '0, err);
        this.set_tid(tid);
        this.set_tdest(tdest);
        this.set_tuser(tuser);
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        super.destroy();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    function automatic TID_T get_tid();
        META_T __meta = this.get_meta();
        return __meta.tid;
    endfunction

    function automatic void set_tid(TID_T tid);
        META_T __meta = this.get_meta();
        __meta.tid = tid;
        this.set_meta(__meta);
    endfunction

    function automatic TDEST_T get_tdest();
        META_T __meta = this.get_meta();
        return __meta.tdest;
    endfunction

    function automatic void set_tdest(TDEST_T tdest);
        META_T __meta = this.get_meta();
        __meta.tdest = tdest;
        this.set_meta(__meta);
    endfunction

    function automatic TUSER_T get_tuser();
        META_T __meta = this.get_meta();
        return __meta.tuser;
    endfunction

    function automatic void set_tuser(TUSER_T tuser);
        META_T __meta = this.get_meta();
        __meta.tuser = tuser;
        this.set_meta(__meta);
    endfunction

    // Construct raw packet from array of bytes
    static function axi4s_transaction#(TID_T, TDEST_T, TUSER_T) create_from_bytes(
            input string name = "axi4s_transaction",
            input byte data[],
            input TID_T tid = '0,
            input TDEST_T tdest = '0,
            input TUSER_T tuser = '0,
            input bit err = 1'b0
        );
        axi4s_transaction#(TID_T, TDEST_T, TUSER_T) new_transaction = new(name, data.size(), tid, tdest, tuser, err);
        new_transaction.set_from_bytes(data);
        return new_transaction;
    endfunction

    function automatic axi4s_transaction#(TID_T, TDEST_T, TUSER_T) clone(input string name);
        axi4s_transaction#(TID_T, TDEST_T, TUSER_T) cloned_transaction =
            axi4s_transaction#(TID_T, TDEST_T, TUSER_T)::create_from_bytes(
                name,
                this.to_bytes,
                this.get_tid(),
                this.get_tdest(),
                this.get_tuser(),
                this.is_errored()
            );
        return cloned_transaction;
    endfunction

    // Get string representation of transaction
    // [[ implements std_verif_pkg::transaction.to_string() ]]
    function string to_string();
        string str = $sformatf("AXI4-S transaction: %s\n", get_name());
        str = {str, "------------------------------------------\n"};
        str = {str, $sformatf("TID: %x, TDEST: %x, TUSER: %x\n", this.get_tid(), this.get_tdest(), this.get_tuser())};
        str = {str, "------------------------------------------\n"};
        str = {str, super.to_string()};
        return str;
    endfunction

    // Compare transaction to a reference transaction
    // [[ implements std_verif_pkg::transaction.compare() ]]
    virtual function bit _compare(input axi4s_transaction#(TID_T, TDEST_T, TUSER_T) b, output string msg);
        if (this.get_tid() !== b.get_tid()) begin
            msg = $sformatf("Mismatch in 'tid' field. A: %x, B: %x.", this.get_tid(), b.get_tid());
            return 0;
        end else if (this.get_tdest() !== b.get_tdest()) begin
            msg = $sformatf("Mismatch in 'tdest' field. A: %x, B: %x.", this.get_tdest(), b.get_tdest());
            return 0;
        end else if (this.get_tuser() != b.get_tuser()) begin
            msg = $sformatf("Mismatch in 'tuser' field. A: %x, B: %x.", this.get_tuser(), b.get_tuser());
            return 0;
        end else return super._compare(b, msg);
    endfunction
endclass
