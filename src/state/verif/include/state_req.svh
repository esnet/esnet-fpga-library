class state_req#(parameter type ID_T = bit, parameter type UPDATE_T = bit) extends std_verif_pkg::transaction;

    local static const string __CLASS_NAME = "state_verif_pkg::state_req";

    //===================================
    // Properties
    //===================================
    ID_T id;
    update_ctxt_t ctxt;
    bit init;
    rand UPDATE_T update;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name="state_req",
            input ID_T id,
            input update_ctxt_t ctxt,
            input bit init = 1'b0
        );
        super.new(name);
        this.ctxt = ctxt;
        this.id = id;
        this.init = init;
        // WORKAROUND-INIT-PROPS {
        //     Provide/repeat default assignments for all remaining instance properties here.
        //     Works around an apparent object initialization bug (as of Vivado 2024.2)
        //     where properties are not properly allocated when they are not assigned
        //     in the constructor.
        this.update = 0;
        // } WORKAROUND-INIT-PROPS
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

    // Copy from reference
    // [[ implements std_verif_pkg::transaction._copy() ]]
    virtual protected function automatic void _copy(input std_verif_pkg::transaction t2);
        state_req#(ID_T, UPDATE_T) req;
        if (!$cast(req, t2)) begin
            // Impossible to continue; raise fatal exception.
            $fatal(2, $sformatf("Type mismatch while copying '%s' to '%s'", t2.get_name(), this.get_name()));
        end
        this.id = req.id;
        this.ctxt = req.ctxt;
        this.init = req.init;
        this.update = req.update;
    endfunction

    static function state_req#(ID_T,UPDATE_T) create_from_update(
            input string name, input ID_T id, input update_ctxt_t ctxt, input bit init, input UPDATE_T update
        );
        state_req#(ID_T,UPDATE_T) new_req = new(name, id, ctxt, init);
        new_req.set_from_update(update);
        return new_req;
    endfunction

    function automatic void set_from_update(input UPDATE_T update);
        this.update = update;
    endfunction

    // Get string representation of transaction
    // [[ implements std_verif_pkg::transaction.to_string() ]]
    function automatic string to_string();
        string str;
        str = $sformatf("State update request '%s':\n", get_name());
        str = {str, $sformatf("\tCTXT:   %s\n", this.ctxt.name())};
        str = {str, $sformatf("\tID:     %d\n", this.id)};
        str = {str, $sformatf("\tUPDATE: 0x%x\n", this.update)};
        str = {str, $sformatf("\tINIT:   %b\n", this.init)};
        return str;
    endfunction

    // Compare transaction against another
    // [[ implements std_verif_pkg::transaction.compare() ]]
    function automatic bit compare(input std_verif_pkg::transaction t2, output string msg);
        state_req#(ID_T, UPDATE_T) b;
        // Upcast generic transaction to raw transaction type
        if (!$cast(b, t2)) begin
            msg = $sformatf("Transaction type mismatch. Transaction '%s' is not of type %s or has unexpected parameterization.", t2.get_name(), __CLASS_NAME);
            return 0;
        end
        if (this.ctxt !== b.ctxt) begin
            msg = $sformatf(
                "Mismatch while comparing contexts. A: %s, B: %s.",
                this.ctxt.name(),
                b.ctxt.name()
            );
            return 0;
        end
        if (this.id !== b.id) begin
            msg = $sformatf(
                "Mismatch while comparing ID values. A: %d, B: %d.",
                this.id,
                b.id
            );
            return 0;
        end
        if (this.update !== b.update) begin
            msg = $sformatf(
                "Mismatch while comparing UPDATE values. A: 0x%0x, B: 0x%0x.",
                this.update,
                b.update
            );
            return 0;
        end else if (this.init !== b.init) begin
            msg = $sformatf(
                "Mismatch while comparing INIT values. A: %b, B: %b.",
                this.init,
                b.init
            );
            return 0;
        end
        msg = "State update requests match.";
        return 1;
    endfunction

endclass : state_req
