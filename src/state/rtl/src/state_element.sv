module state_element
    import state_pkg::*;
#(
    parameter element_t SPEC = DEFAULT_STATE_ELEMENT,
    parameter int NUM_TRANSACTIONS = 8, // Maximum number of transactions that can
                                         // be in flight (from the perspective of this module)
                                         // at any given time. Typically equal to the (max)
                                         // read latency.
    // Derived parameters (don't override)
    parameter int UPDATE_WID = SPEC.UPDATE_WID > 0 ? SPEC.UPDATE_WID : 1,
    parameter type STATE_T = logic[SPEC.STATE_WID-1:0],
    parameter type UPDATE_T = logic[UPDATE_WID-1:0]
)(
    // Clock/reset
    input  logic         clk,
    input  logic         srst,

    // Control
    input  logic         en,

    // Update interface
    input  update_ctxt_t ctxt,
    input  STATE_T       prev_state,
    input  UPDATE_T      update,
    input  logic         init,
    output STATE_T       next_state,
    output STATE_T       return_state
);
    // -----------------------------
    // Parameter checking
    // -----------------------------
    initial begin
        case (SPEC.TYPE)
            ELEMENT_TYPE_FLAGS,
            ELEMENT_TYPE_WRITE,
            ELEMENT_TYPE_WRITE_IF_ZERO,
            ELEMENT_TYPE_SEQ : std_pkg::param_check(SPEC.UPDATE_WID, SPEC.STATE_WID, "UPDATE_WID", $sformatf("State and update widths must be equal for element type '%s'.", getElementTypeString(SPEC.TYPE)));
            ELEMENT_TYPE_WRITE_N_TIMES : begin
                std_pkg::param_check(SPEC.UPDATE_WID, SPEC.STATE_WID, "UPDATE_WID", $sformatf("State and update widths must be equal for element type '%s'.", getElementTypeString(SPEC.TYPE)));
                std_pkg::param_check_gt(SPEC.STATE_WID, 5, "STATE_WID", $sformatf("State width must be at least 5 bits for element type '%s'.", getElementTypeString(SPEC.TYPE)));
            end
            ELEMENT_TYPE_COUNTER      : std_pkg::param_check(SPEC.UPDATE_WID, 0,              "UPDATE_WID", "Counter has no update vector, i.e. UPDATE_WID must be zero.");
            ELEMENT_TYPE_COUNTER_COND : std_pkg::param_check(SPEC.UPDATE_WID, 1,              "UPDATE_WID", "Conditional counter requires 1-bit update vector.");
        endcase
    end

    // ----------------------------------
    // Signals 
    // ----------------------------------
    STATE_T next_state__datapath;
    STATE_T next_state__control;
    STATE_T next_state__reap;
    
    // -----------------------------
    // Datapath state update
    // -----------------------------
    always_comb begin
        next_state__datapath = prev_state;
        if (en) begin
            case (SPEC.TYPE)
                ELEMENT_TYPE_WRITE : begin
                    next_state__datapath = STATE_T'(update);
                end
                ELEMENT_TYPE_WRITE_IF_ZERO: begin
                    if (init)                  next_state__datapath = STATE_T'(update);
                    else if (prev_state == '0) next_state__datapath = STATE_T'(update);
                end
                ELEMENT_TYPE_WRITE_N_TIMES: begin
                    if (init) begin
                        if ((update & 4'hF) > 0)                        next_state__datapath = update;
                        else                                            next_state__datapath = '0;
                    end else if ((prev_state & 4'hF) < (update & 4'hF)) next_state__datapath = update;
                    else                                                next_state__datapath = prev_state;
                    next_state__datapath = (next_state__datapath >> 4) << 4;
                    if (init)                             next_state__datapath |= 1;
                    else if ((prev_state & 4'hF) < 4'd15) next_state__datapath |= (prev_state & 4'hF) + 1;
                    else                                  next_state__datapath |= 4'd15;
                end
                ELEMENT_TYPE_FLAGS : begin
                    if (init) next_state__datapath = STATE_T'(update);
                    else      next_state__datapath = prev_state | STATE_T'(update);
                end
                ELEMENT_TYPE_COUNTER : begin
                    if (init) next_state__datapath = 1;
                    else      next_state__datapath = prev_state + 1;
                end
                ELEMENT_TYPE_COUNTER_COND : begin
                    if (init) next_state__datapath = {'0, update[0]};
                    else      next_state__datapath = update[0] ? prev_state + 1 : prev_state;
                end
                ELEMENT_TYPE_COUNT : begin
                    if (init) next_state__datapath = {'0, update};
                    else      next_state__datapath = prev_state + update;
                end
                ELEMENT_TYPE_SEQ : begin
                    if (init)                                   next_state__datapath = STATE_T'(update);
                    else if (STATE_T'(update) - prev_state > 0) next_state__datapath = STATE_T'(update);
                    else                                        next_state__datapath = prev_state;
                end
                default : begin
                    next_state__datapath = prev_state;
                end
            endcase
        end
    end

    // -----------------------------
    // Control state update
    // -----------------------------
    always_comb begin
        next_state__control = prev_state;
        case (SPEC.TYPE)
            ELEMENT_TYPE_READ : next_state__control = STATE_T'(update);
            default           : next_state__control = prev_state;
        endcase
    end

    // -----------------------------
    // Reap state update
    // -----------------------------
    always_comb begin
        next_state__reap = prev_state;
        case (SPEC.REAP_MODE)
            REAP_MODE_CLEAR   : next_state__reap = '0;
            REAP_MODE_PERSIST : next_state__reap = prev_state;
            REAP_MODE_UPDATE  : next_state__reap = next_state__control;
            default           : next_state__reap = prev_state;
        endcase
    end

    // -----------------------------
    // State update
    // -----------------------------
    always_comb begin
        next_state = prev_state;
        case (ctxt)
            UPDATE_CTXT_DATAPATH : next_state = next_state__datapath;
            UPDATE_CTXT_CONTROL  : next_state = next_state__control;
            UPDATE_CTXT_REAP     : next_state = next_state__reap;
            default              : next_state = prev_state;
        endcase
    end
   
    // -----------------------------
    // Return state
    // -----------------------------
    always_comb begin
        return_state = prev_state;
        case (SPEC.RETURN_MODE)
            RETURN_MODE_PREV_STATE : return_state = prev_state;
            RETURN_MODE_NEXT_STATE : return_state = next_state;
            RETURN_MODE_DELTA      : return_state = next_state - prev_state;
            default                : return_state = prev_state;
        endcase
    end
  
endmodule : state_element
