// State element model (+ predictor)
class state_element_model #(
    parameter type ID_T = bit,
    parameter type STATE_T = bit,
    parameter type UPDATE_T = bit
) extends state_model#(ID_T, STATE_T, UPDATE_T);

    local static const string __CLASS_NAME = "state_verif_pkg::state_element_model";

    //===================================
    // Properties
    //===================================
    local element_t __SPEC;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name="state_element_model",
            input element_t SPEC=DEFAULT_STATE_ELEMENT
        );
        super.new(name);
        __SPEC = SPEC;
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

    // Calculate next state, given previous state and update (datapath updates)
    protected function automatic STATE_T _get_next_state_datapath(input STATE_T prev_state, input UPDATE_T update, input bit init=1'b0);
        STATE_T next_state;
        STATE_T __next_state;

        // Enforce specified size on inputs
        STATE_T  __prev_state = prev_state & (2**__SPEC.STATE_WID-1);
        UPDATE_T __update = update & (2**__SPEC.UPDATE_WID-1);

        // Next state calculation
        case (__SPEC.TYPE)
            ELEMENT_TYPE_READ : __next_state = __prev_state;
            ELEMENT_TYPE_WRITE : __next_state = __update;
            ELEMENT_TYPE_WRITE_COND : begin
                if (|(__update & 1)) __next_state = __update >> 1;
                else if (init)       __next_state = '0;
                else                 __next_state = __prev_state;
            end
            ELEMENT_TYPE_WRITE_IF_ZERO : begin
                if (init)                    __next_state = __update;
                else if (__prev_state == '0) __next_state = __update;
                else                         __next_state = __prev_state;
            end
            ELEMENT_TYPE_WRITE_N_TIMES : begin
                if (init) begin
                    if ((__update & 4'hF) > 0) __next_state = __update;
                    else                       __next_state = '0;
                end else if ((__prev_state & 4'hF) < (__update & 4'hF)) __next_state = __update;
                else __next_state = __prev_state;
                __next_state = (__next_state >> 4) << 4;
                if (init) __next_state |= 1;
                else if ((__prev_state & 4'hF) < 4'd15) __next_state |= (__prev_state & 4'hF) + 1;
                else __next_state |= 4'd15;
            end
            ELEMENT_TYPE_FLAGS : begin
                if (init) __next_state = __update;
                else      __next_state = __prev_state | __update;
            end
            ELEMENT_TYPE_COUNTER : begin
                if (init) __next_state = 1;
                else      __next_state = __prev_state + 1;
            end
            ELEMENT_TYPE_COUNTER_COND : begin
                if (init) __next_state = __update & 1;
                else      __next_state = __prev_state + (__update & 1);
            end
            ELEMENT_TYPE_COUNT : begin
                if (init) __next_state = __update;
                else      __next_state = __prev_state + __update;
            end
            ELEMENT_TYPE_SEQ : begin
                STATE_T exp_seq;
                STATE_T new_seq;
                STATE_T got_seq;
                got_seq = __update & (2**__SPEC.STATE_WID-1);
                new_seq = got_seq + (update >> __SPEC.STATE_WID);
                exp_seq = __prev_state;
                if (init) __next_state = new_seq;
                else if ($signed(got_seq - exp_seq) > 0) __next_state = new_seq;
                else if ($signed(got_seq - exp_seq) < 0) __next_state = exp_seq;
                else                                     __next_state = new_seq;
            end
            default : __next_state = __prev_state;
        endcase

        // Enforce specified size on output
        next_state = __next_state & (2**__SPEC.STATE_WID-1);

        return next_state;
    endfunction

    // Calculate next state, given previous state and update (control updates)
    protected function automatic STATE_T _get_next_state_control(input STATE_T prev_state, input UPDATE_T update, input bit init=1'b0);
        STATE_T next_state;
        STATE_T __next_state;

        // Enforce specified size on inputs
        STATE_T  __prev_state = prev_state & (2**__SPEC.STATE_WID-1);
        UPDATE_T __update = update & (2**__SPEC.UPDATE_WID-1);

        // Return calculation
        case (__SPEC.TYPE)
            ELEMENT_TYPE_READ : __next_state = __update;
            default           : __next_state = __prev_state;
        endcase

        // Enforce specified size on output
        next_state = __next_state & (2**__SPEC.STATE_WID-1);

        return next_state;
    endfunction

    // Calculate next state, given previous state and update (reap operations)
    protected function automatic STATE_T _get_next_state_reap(input STATE_T prev_state, input UPDATE_T update, input bit init=1'b0);
        STATE_T next_state;
        STATE_T __next_state;

        // Enforce specified size on inputs
        STATE_T  __prev_state = prev_state & (2**__SPEC.STATE_WID-1);
        UPDATE_T __update = update & (2**__SPEC.UPDATE_WID-1);

        // Return calculation
        case (__SPEC.REAP_MODE)
            REAP_MODE_CLEAR : __next_state = '0;
            default         : __next_state = __prev_state;
        endcase

        // Enforce specified size on output
        next_state = __next_state & (2**__SPEC.STATE_WID-1);

        return next_state;
    endfunction

    // Calculate return state, given update context, previous state and update
    // [[ implements get_return_state() virtual task of state_model class ]]
    function automatic STATE_T get_next_state(
            input update_ctxt_t ctxt,
            input STATE_T prev_state,
            input UPDATE_T update,
            input bit init=1'b0
        );
        case (ctxt)
            UPDATE_CTXT_DATAPATH : return _get_next_state_datapath(prev_state, update, init);
            UPDATE_CTXT_CONTROL  : return _get_next_state_control(prev_state, update, init);
            UPDATE_CTXT_REAP     : return _get_next_state_reap(prev_state, update, init);
            default              : return prev_state;
        endcase
    endfunction

    // Calculate return state, given previous state and update
    // [[ implements get_return_state() virtual task of state_model class ]]
    function automatic STATE_T get_return_state(input STATE_T prev_state, input STATE_T next_state);
        STATE_T return_state;
        STATE_T __return_state;

        // Enforce specified size on inputs
        STATE_T __prev_state = prev_state & (2**__SPEC.STATE_WID-1);
        STATE_T __next_state = next_state & (2**__SPEC.STATE_WID-1);

        // Return calculation
        case (__SPEC.RETURN_MODE)
            RETURN_MODE_PREV_STATE : __return_state = __prev_state;
            RETURN_MODE_NEXT_STATE : __return_state = __next_state;
            RETURN_MODE_DELTA      : __return_state = __next_state - __prev_state;
            default                : __return_state = __prev_state;
        endcase

        // Enforce specified size on output
        return_state = __return_state & (2**__SPEC.STATE_WID-1);

        return return_state;
    endfunction

endclass : state_element_model
