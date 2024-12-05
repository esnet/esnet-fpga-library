// State vector model (+ predictor)
class state_vector_model #(
    parameter type ID_T = bit,
    parameter type STATE_T = bit,
    parameter type UPDATE_T = bit
) extends state_model#(ID_T,STATE_T,UPDATE_T);

    local static const string __CLASS_NAME = "state_verif_pkg::state_vector_model";

    //===================================
    // Properties
    //===================================
    local vector_t __SPEC;
    local state_element_model#(ID_T, STATE_T, UPDATE_T) __model [];

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name="state_vector_model",
            input vector_t SPEC
        );
        super.new(name);
        __SPEC = SPEC;
        // Create per-element models
        __model = new[SPEC.NUM_ELEMENTS];
        foreach (__model[i]) __model[i] = new(.SPEC(SPEC.ELEMENTS[i]));
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        __model.delete();
        super.destroy();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    // Calculate next state, given previous state and update (datapath updates)
    // [[ implements get_next_state() virtual task of state_model base class ]]
    function automatic STATE_T get_next_state(input update_ctxt_t ctxt, input STATE_T prev_state, input UPDATE_T update, input bit init);
        STATE_T next_state;
        STATE_T __prev_state;
        STATE_T __element_prev_state [] = new[this.__SPEC.NUM_ELEMENTS];
        UPDATE_T __update;
        UPDATE_T __element_update[] = new[this.__SPEC.NUM_ELEMENTS];

        // Distribute prev_state and update vectors to individual state elements
        __update = update;
        __prev_state = prev_state;
        for (int i = 0; i < this.__SPEC.NUM_ELEMENTS; i++) begin
            element_t ELEMENT = this.__SPEC.ELEMENTS[i];
            __element_prev_state[i] = __prev_state & (2**ELEMENT.STATE_WID-1);
            __prev_state = __prev_state >> ELEMENT.STATE_WID;
            if (ELEMENT.UPDATE_WID > 0) begin
                __element_update[i] = __update & (2**ELEMENT.UPDATE_WID-1);
                __update = __update >> ELEMENT.UPDATE_WID;
            end else begin
                __element_update[i] = '0;
            end
        end

        // Combine state outputs from individual outputs into composite state vector
        next_state = 0;
        for (int i = this.__SPEC.NUM_ELEMENTS-1; i >= 0; i--) begin
            element_t ELEMENT = this.__SPEC.ELEMENTS[i];
            next_state = (next_state << ELEMENT.STATE_WID) | __model[i].get_next_state(ctxt, __element_prev_state[i], __element_update[i], init);
        end
        return next_state;
    endfunction

    // Calculate return state, given previous state and update
    // [[ implements get_return_state() virtual task of state_model class ]]
    function automatic STATE_T get_return_state(input STATE_T prev_state, input STATE_T next_state);
        STATE_T return_state;
        STATE_T __prev_state;
        STATE_T __next_state;
        STATE_T __element_prev_state [] = new[this.__SPEC.NUM_ELEMENTS];
        STATE_T __element_next_state [] = new[this.__SPEC.NUM_ELEMENTS];

        // Distribute prev/next state vectors to individual state elements
        __prev_state = prev_state;
        __next_state = next_state;
        for (int i = 0; i < this.__SPEC.NUM_ELEMENTS; i++) begin
            element_t ELEMENT = this.__SPEC.ELEMENTS[i];
            __element_prev_state[i] = __prev_state & (2**ELEMENT.STATE_WID-1);
            __prev_state = __prev_state >> ELEMENT.STATE_WID;
            __element_next_state[i] = __next_state & (2**ELEMENT.STATE_WID-1);
            __next_state = __next_state >> ELEMENT.STATE_WID;
        end

        // Combine state outputs from individual outputs into composite state vector
        return_state = 0;
        for (int i = this.__SPEC.NUM_ELEMENTS-1; i >= 0; i--) begin
            element_t ELEMENT = this.__SPEC.ELEMENTS[i];
            return_state = (return_state << ELEMENT.STATE_WID) | __model[i].get_return_state(__element_prev_state[i], __element_next_state[i]);
        end

        return return_state;
    endfunction

endclass : state_vector_model
