package state_pkg;

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef enum logic[7:0] {
        BLOCK_TYPE_UNSPECIFIED = 0,
        BLOCK_TYPE_ELEMENT,
        BLOCK_TYPE_VECTOR,
        BLOCK_TYPE_CACHE
    } block_type_t;

    // State element
    typedef enum {
        ELEMENT_TYPE_UNSPECIFIED = 0,
        ELEMENT_TYPE_READ,
        ELEMENT_TYPE_WRITE,
        ELEMENT_TYPE_WRITE_COND,
        ELEMENT_TYPE_WRITE_IF_ZERO,
        ELEMENT_TYPE_WRITE_N_TIMES,
        ELEMENT_TYPE_FLAGS,
        ELEMENT_TYPE_COUNTER,
        ELEMENT_TYPE_COUNTER_COND,
        ELEMENT_TYPE_COUNT,
        ELEMENT_TYPE_SEQ
    } element_type_t;

    typedef enum {
        RETURN_MODE_PREV_STATE, // Returns previous state
        RETURN_MODE_NEXT_STATE, // Returns next (updated) state
        RETURN_MODE_DELTA       // Returns difference between new and previous state
    } return_mode_t;

    typedef enum {
        REAP_MODE_CLEAR,
        REAP_MODE_PERSIST,
        REAP_MODE_UPDATE
    } reap_mode_t;

    typedef enum logic [1:0] {
        UPDATE_CTXT_NOP,
        UPDATE_CTXT_DATAPATH,
        UPDATE_CTXT_CONTROL,
        UPDATE_CTXT_REAP
    } update_ctxt_t;

    typedef struct {
        element_type_t TYPE;
        int STATE_WID;
        int UPDATE_WID;
        return_mode_t RETURN_MODE;
        reap_mode_t REAP_MODE;
    } element_t;

    localparam element_t DEFAULT_STATE_ELEMENT = '{
        TYPE : ELEMENT_TYPE_UNSPECIFIED,
        STATE_WID : 1,
        UPDATE_WID : 1,
        RETURN_MODE : RETURN_MODE_PREV_STATE,
        REAP_MODE : REAP_MODE_CLEAR
    };

    // State vector
    localparam int STATE_VECTOR_MAX_ELEMENTS = 24;

    typedef struct {
        int NUM_ELEMENTS;
        element_t ELEMENTS[STATE_VECTOR_MAX_ELEMENTS];
    } vector_t;

    localparam vector_t DEFAULT_STATE_VECTOR = '{
        NUM_ELEMENTS: 1,
        ELEMENTS: '{default: DEFAULT_STATE_ELEMENT}
    };

    // Notifications
    typedef enum logic [1:0] {
        EXPIRY_NONE = 0,
        EXPIRY_IDLE,
        EXPIRY_ACTIVE,
        EXPIRY_DONE
    } expiry_msg_t;

    // -----------------------------
    // Functions
    // -----------------------------
    function automatic string getElementTypeString(input element_type_t TYPE);
        case (TYPE)
            ELEMENT_TYPE_READ          : return "read";
            ELEMENT_TYPE_WRITE         : return "write";
            ELEMENT_TYPE_WRITE_COND    : return "write_cond";
            ELEMENT_TYPE_WRITE_IF_ZERO : return "write_if_zero";
            ELEMENT_TYPE_WRITE_N_TIMES : return "write_N_times";
            ELEMENT_TYPE_FLAGS         : return "flags";
            ELEMENT_TYPE_COUNTER       : return "counter";
            ELEMENT_TYPE_COUNTER_COND  : return "counter_cond";
            ELEMENT_TYPE_COUNT         : return "count";
            ELEMENT_TYPE_SEQ           : return "seq";
            default                    : return "unspecified";
        endcase
    endfunction

    function automatic int getStateVectorSize(input vector_t SPEC);
        automatic int size = 0;
        for (int i = 0; i < SPEC.NUM_ELEMENTS; i++) begin
            automatic element_t ELEMENT = SPEC.ELEMENTS[i];
            size += ELEMENT.STATE_WID;
        end
        return size;
    endfunction

    function automatic int getUpdateVectorSize(input vector_t SPEC);
        automatic int size = 0;
        for (int i = 0; i < SPEC.NUM_ELEMENTS; i++) begin
            automatic element_t ELEMENT = SPEC.ELEMENTS[i];
            size += ELEMENT.UPDATE_WID;
        end
        // Account for zero-width update fields (e.g. COUNTER)
        if (size > 0) return size;
        else          return 1;
    endfunction

    function automatic int getStateVectorOffset(input vector_t SPEC, input int element_id);
        automatic int offset = 0;
        for (int i = 0; i < element_id; i++) begin
            automatic element_t ELEMENT = SPEC.ELEMENTS[i];
            offset += ELEMENT.STATE_WID;
        end
        return offset;
    endfunction

    function automatic int getUpdateVectorOffset(input vector_t SPEC, input int element_id);
        automatic int offset = 0;
        for (int i = 0; i < element_id; i++) begin
            automatic element_t ELEMENT = SPEC.ELEMENTS[i];
            offset += ELEMENT.UPDATE_WID;
        end
        return offset;
    endfunction

    // -------------------------------------
    // Parameterized classes (functions)
    // -------------------------------------
    virtual class State#(type ID_T=bit[7:0]);
        static function int numIDs();
            return 2**$bits(ID_T);
        endfunction
    endclass

    // -------------------------------------
    // Standard state element definitions
    // -------------------------------------
    localparam element_t ELEMENT_CONTROL_FLAG = '{
        TYPE : ELEMENT_TYPE_READ,
        STATE_WID : 1,
        UPDATE_WID : 1,
        RETURN_MODE : RETURN_MODE_PREV_STATE,
        REAP_MODE : REAP_MODE_PERSIST
    };

endpackage : state_pkg
