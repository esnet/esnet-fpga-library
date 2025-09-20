class state_monitor #(
    parameter type ID_T = bit,
    parameter type STATE_T = bit,
    parameter type UPDATE_T = bit
) extends std_verif_pkg::monitor#(state_resp#(ID_T,STATE_T));

    local static const string __CLASS_NAME = "state_verif_pkg::state_monitor";

    localparam int ID_WID = $bits(ID_T);
    localparam int STATE_WID = $bits(STATE_T);
    localparam int UPDATE_WID = $bits(UPDATE_T);

    //===================================
    // Properties
    //===================================
    virtual state_intf #(ID_WID, STATE_WID, UPDATE_WID) update_vif;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(input string name="state_monitor");
        super.new(name);
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
        // Nothing to do
    endtask

    // Wait for interface to be ready to accept transactions (after reset/init, for example)
    task wait_ready();
        update_vif.wait_ready();
    endtask

    // Receive transaction from interface
    // [[ implements _receive() virtual method of std_verif_pkg::monitor parent class ]]
    protected task _receive(output state_resp#(ID_T, STATE_T) transaction);
        STATE_T rx_state;
        bit __timeout;
        static int __rx_count = 0;

        debug_msg("Waiting for transaction...");

        update_vif.receive(rx_state, __timeout);
        
        transaction = new($sformatf("state_resp[%0d]", __rx_count++), rx_state);

        debug_msg($sformatf("Received %s.\n%s", transaction.get_name(), transaction.to_string()));
    endtask

endclass : state_monitor
