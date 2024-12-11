// Reference model for state components
// - abstract class (not to be instantiated directly)
// - derived classes must describe the state update
//   (i.e. increment for counter, bitwise OR for flags, etc.)
virtual class state_model #(
    parameter type ID_T = bit,
    parameter type STATE_T = bit,
    parameter type UPDATE_T = bit
) extends std_verif_pkg::predictor#(state_req#(ID_T,UPDATE_T), state_resp#(STATE_T));

    local static const string __CLASS_NAME = "state_verif_pkg::state_model";

    //===================================
    // Properties
    //===================================
    local db_model#(ID_T,STATE_T) __db_model;

    local const int __NUM_IDS = 2**$bits(ID_T);

    //===================================
    // Pure Virtual Methods
    // (must be implemented by derived class)
    //===================================
    // Calculate next state after datapath update, given previous state and update vectors
    pure virtual function automatic STATE_T get_next_state(input update_ctxt_t ctxt, input STATE_T prev_state, input UPDATE_T update, input bit init);
    // Calculate return state, given previous state and update
    pure virtual function automatic STATE_T get_return_state(input STATE_T prev_state, input STATE_T next_state);

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name="state_model"
        );
        super.new(name);
        this.__db_model = new("db_model", __NUM_IDS);
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        __db_model = null;
        super.destroy();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Reset model
    // [[ implements std_verif_pkg::model._reset() ]]
    virtual protected function automatic void _reset();
        trace_msg("_reset()");
        __db_model.reset();
        super._reset();
        trace_msg("_reset() Done.");
    endfunction

    // GET (from control plane)
    function automatic db_pkg::status_t get(
            input ID_T id,
            output bit valid,
            output STATE_T state
        );
        return __db_model.get(id, valid, state);
    endfunction

    // SET (from control plane)
    function automatic db_pkg::status_t set(
            input ID_T id,
            input STATE_T state
        );
        return __db_model.set(id, state);
    endfunction

    // UNSET (from control plane)
    function automatic db_pkg::status_t unset(
            input ID_T id,
            output bit valid,
            output STATE_T state
        );
        return __db_model.unset(id, valid, state);
    endfunction

    // REPLACE (from control plane)
    function automatic db_pkg::status_t replace(
            input ID_T id,
            input STATE_T new_state,
            output bit valid,
            output STATE_T prev_state
        );
        return __db_model.replace(id, new_state, valid, prev_state);
    endfunction

    // NOP (from control plane)
    function automatic db_pkg::status_t nop();
        return __db_model.nop();
    endfunction

    // CLEAR (from control plane)
    function automatic db_pkg::status_t clear_all();
        return __db_model.clear_all();
    endfunction

    // Update (from data plane)
    function automatic STATE_T update(
            input update_ctxt_t ctxt,
            input ID_T id,
            input UPDATE_T _update,
            input bit init=1'b0
        );
        bit _valid_unused;
        STATE_T prev_state;
        STATE_T next_state;
        db_pkg::status_t status;
        status = get(id, _valid_unused, prev_state);
        if (status != db_pkg::STATUS_OK)
            error_msg($sformatf("Error retrieving previous state for ID 0x%0x.", id));
        next_state = get_next_state(ctxt, prev_state, _update, init);
        status = set(id, next_state);
        if (status != db_pkg::STATUS_OK)
            error_msg($sformatf("Failed to set new state for ID 0x%0x.", id));
        return get_return_state(prev_state, next_state);
    endfunction

    // Process input transaction
    // [[ implements std_verif_pkg::predictor.predict() ]]
    function automatic TRANSACTION_OUT_T predict(input TRANSACTION_IN_T transaction);
        TRANSACTION_OUT_T transaction_out;
        STATE_T state;

        trace_msg("--- predict() ---");

        // Update state
        state = update(transaction.ctxt, transaction.id, transaction.update, transaction.init);

        // Build output transaction
        transaction_out = new(
            $sformatf("state_resp_transaction[%0d]", num_input_transactions()),
            state
        );
        
        trace_msg("--- predict() Done. ---");

        return transaction_out;

    endfunction : predict

endclass : state_model
