class state_req#(
    parameter type ID_T = bit,
    parameter type UPDATE_T = bit
) extends std_verif_pkg::transaction;

    local static const string __CLASS_NAME = "state_verif_pkg::state_req";

    //===================================
    // Properties
    //===================================
    const ID_T id;
    const update_ctxt_t ctxt;
    const bit init;
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
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
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
    // [[ implements to_string virtual method of std_verif_pkg::transaction ]]
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
    // [[ implements compare virtual method of std_verif_pkg::transaction ]]
    function automatic bit compare(input state_req#(ID_T,UPDATE_T) t2, output string msg);
        if (this.ctxt !== t2.ctxt) begin
            msg = $sformatf(
                "Mismatch while comparing contexts. A: %s, B: %s.",
                this.ctxt.name(),
                t2.ctxt.name()
            );
            return 0;
        end
        if (this.id !== t2.id) begin
            msg = $sformatf(
                "Mismatch while comparing ID values. A: %d, B: %d.",
                this.id,
                t2.id
            );
            return 0;
        end
        if (this.update !== t2.update) begin
            msg = $sformatf(
                "Mismatch while comparing UPDATE values. A: 0x%0x, B: 0x%0x.",
                this.update,
                t2.update
            );
            return 0;
        end else if (this.init !== t2.init) begin
            msg = $sformatf(
                "Mismatch while comparing INIT values. A: %b, B: %b.",
                this.init,
                t2.init
            );
            return 0;
        end
        msg = "State update requests match.";
        return 1;
    endfunction

endclass : state_req
