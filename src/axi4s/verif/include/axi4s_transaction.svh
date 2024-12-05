class axi4s_transaction #(
    parameter type TID_T = bit,
    parameter type TDEST_T = bit,
    parameter type TUSER_T = bit,
    // Derived parameters (don't override)
    parameter type META_T = struct packed {TID_T tid; TDEST_T tdest; TUSER_T tuser;}
) extends packet_verif_pkg::packet_raw#(META_T);

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

    // Copy from reference
    // [[ implements std_verif_pkg::transaction._copy() ]]
    virtual protected function automatic void _copy(input std_verif_pkg::transaction t2);
        axi4s_transaction#(TID_T, TDEST_T, TUSER_T) trans;
        super._copy(t2);
        if (!$cast(trans, t2)) begin
            // Impossible to continue; raise fatal exception.
            $fatal(2, "Transaction type mismatch during object copy operation.");
        end
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
        new_transaction.from_bytes(data);
        return new_transaction;
    endfunction

    // Duplicate transaction
    //  - enhanced version of clone() that includes the upcast to packet type and
    //    allows for transaction renaming
    virtual function automatic axi4s_transaction#(TID_T, TDEST_T, TUSER_T) dup(input string name=get_name());
        axi4s_transaction#(TID_T, TDEST_T, TUSER_T) trans;
        if (!$cast(trans, this.clone())) begin
            // Impossible to continue; raise fatal exception.
            $fatal(2, "Dynamic cast failure during object duplication. This should never happen.");
        end
        trans.set_name(name);
        return trans;
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
    virtual function automatic bit compare(input std_verif_pkg::transaction t2, output string msg);
        axi4s_transaction#(TID_T, TDEST_T, TUSER_T) b;
        // Cast generic transaction as AXI-S transaction type
        if (!$cast(b, t2)) begin
            msg = $sformatf("Transaction type mismatch. Transaction '%s' is not of type %s or has unexpected parameterization.", t2.get_name(), __CLASS_NAME);
            return 0;
        end
        // Compare packets
        if (this.get_tid() !== b.get_tid()) begin
            msg = $sformatf("Mismatch in 'tid' field. A: %x, B: %x.", this.get_tid(), b.get_tid());
            return 0;
        end else if (this.get_tdest() !== b.get_tdest()) begin
            msg = $sformatf("Mismatch in 'tdest' field. A: %x, B: %x.", this.get_tdest(), b.get_tdest());
            return 0;
        end else if (this.get_tuser() !== b.get_tuser()) begin
            msg = $sformatf("Mismatch in 'tuser' field. A: %x, B: %x.", this.get_tuser(), b.get_tuser());
            return 0;
        end else return super.compare(b, msg);
    endfunction
endclass
