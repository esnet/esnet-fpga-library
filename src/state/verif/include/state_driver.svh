class state_driver #(
    parameter type ID_T = bit,
    parameter type STATE_T = bit,
    parameter type UPDATE_T = bit
) extends std_verif_pkg::driver#(state_req#(ID_T, UPDATE_T));

    local static const string __CLASS_NAME = "state_verif_pkg::state_driver";

    localparam int ID_WID = $bits(ID_T);
    localparam int STATE_WID = $bits(STATE_T);
    localparam int UPDATE_WID = $bits(UPDATE_T);

    //===================================
    // Properties
    //===================================
    virtual state_intf #(ID_WID, STATE_WID, UPDATE_WID) update_vif;

    local state_intf_agent #(ID_T, STATE_T, UPDATE_T) __agent;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="state_driver");
        super.new(name);
        this.__agent = new("driver_agent");
        // WORKAROUND-INIT-PROPS {
        //     Provide/repeat default assignments for all remaining instance properties here.
        //     Works around an apparent object initialization bug (as of Vivado 2024.2)
        //     where properties are not properly allocated when they are not assigned
        //     in the constructor.
        this.update_vif = null;
        // } WORKAROUND-INIT-PROPS
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        update_vif = null;
        super.destroy();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Put (driven) state update interface in idle state
    // [[ implements std_verif_pkg::.component._idle() ]]
    virtual protected task _idle();
        __agent.state_vif = update_vif;
        __agent.idle();
    endtask

    // Wait for interface to be ready to accept transactions (after reset/init, for example)
    task wait_ready();
        bit timeout;
        trace_msg("wait_ready()");
        __agent.state_vif = update_vif;
        __agent.wait_ready(timeout, 0);
        trace_msg("wait_ready() Done.");
    endtask

    // Send typed raw update data with the requested operation context.
    task send_raw(
            input ID_T id, input UPDATE_T update, input bit init=0,
            input update_ctxt_t ctxt=UPDATE_CTXT_DATAPATH
        );
        __agent.state_vif = update_vif;
        case (ctxt)
            UPDATE_CTXT_DATAPATH: __agent.update_req(id, update, init);
            UPDATE_CTXT_CONTROL:  __agent.control_req(id, update, init);
            UPDATE_CTXT_REAP:     __agent.reap_req(id);
            default:              __agent.nop_req(id);
        endcase
    endtask

    // Send transaction to interface
    // [[ implements std_verif_pkg::driver._send() ]]
    protected task _send(
            input state_req#(ID_T, UPDATE_T) transaction
        );
        trace_msg("_send()");
        info_msg($sformatf("Sending transaction '%s'", transaction.get_name()));
        debug_msg($sformatf("Sending:\n%s", transaction.to_string()));

        // Send transaction
        send_raw(transaction.id, transaction.update, transaction.init, transaction.ctxt);

        trace_msg("_send() Done.");
    endtask

endclass : state_driver
