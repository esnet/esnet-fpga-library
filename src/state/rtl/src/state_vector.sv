module state_vector
    import state_pkg::*;
#(
    parameter vector_t SPEC = DEFAULT_STATE_VECTOR,
    parameter int NUM_TRANSACTIONS = 8, // Maximum number of transactions that can
                                        // be in flight (from the perspective of this module)
                                        // at any given time. Typically equal to the (max)
                                        // read latency.
    // Derived parameters (don't override)
    parameter int STATE_WID = getStateVectorSize(SPEC),
    parameter int UPDATE_WID = getUpdateVectorSize(SPEC)
)(
    // Clock/reset
    input  logic         clk,
    input  logic         srst,

    // Control
    input  logic         en,

    // Update interface
    input  update_ctxt_t          ctxt,
    input  logic [STATE_WID-1:0]  prev_state,
    input  logic [UPDATE_WID-1:0] update,
    input  logic                  init,
    output logic [STATE_WID-1:0]  next_state,
    output logic [STATE_WID-1:0]  return_state
);

    // -----------------------------
    // State vector implementation
    // - vector is composed of NUM_ELEMENTS state 'elements',
    //   each of which describes an atomic state update that acts
    //   on a segment of the state vector, using a segment of the
    //   update data
    // -----------------------------
    generate
        for (genvar g_element = 0; g_element < SPEC.NUM_ELEMENTS; g_element++) begin : g__element
            // (Local) Parameters
            localparam element_t ELEMENT_SPEC = SPEC.ELEMENTS[g_element];

            localparam int __STATE_WID = ELEMENT_SPEC.STATE_WID;
            localparam int __UPDATE_WID = ELEMENT_SPEC.UPDATE_WID > 0 ? ELEMENT_SPEC.UPDATE_WID : 1;

            localparam int __STATE_OFFSET = getStateVectorOffset(SPEC, g_element);
            localparam int __UPDATE_OFFSET = getUpdateVectorOffset(SPEC, g_element);
            
            // (Local) Signals
            logic __srst;
            logic __en;

            logic [__STATE_WID-1:0]  __prev_state;
            logic [__UPDATE_WID-1:0] __update;
            logic [__STATE_WID-1:0]  __next_state;
            logic [__STATE_WID-1:0]  __return_state;

            // Pipeline reset
            initial __srst = 1'b1;
            always @(posedge clk) begin
                if (srst) __srst <= 1'b1;
                else      __srst <= 1'b0;
            end

            // Pipeline enable
            initial __en = 1'b1;
            always @(posedge clk) begin
                if (en) __en <= 1'b1;
                else    __en <= 1'b0;
            end

            // Assign local previous state and update inputs from state vector
            assign __prev_state = prev_state[__STATE_OFFSET +: ELEMENT_SPEC.STATE_WID];

            if (ELEMENT_SPEC.UPDATE_WID > 0)
                assign __update = update[__UPDATE_OFFSET +: ELEMENT_SPEC.UPDATE_WID];
            else
                assign __update = '0;

            // Instantiate state element, including state update logic
            state_element #(
                .SPEC             ( ELEMENT_SPEC ),
                .NUM_TRANSACTIONS ( NUM_TRANSACTIONS )
            ) i_state_element (
                .clk          ( clk ),
                .srst         ( __srst ),
                .en           ( __en ),
                .ctxt         ( ctxt ),
                .prev_state   ( __prev_state ),
                .update       ( __update ),
                .init         ( init ),
                .next_state   ( __next_state ),
                .return_state ( __return_state )
            );

            // Map next and return states into state vector
            assign next_state  [__STATE_OFFSET +: ELEMENT_SPEC.STATE_WID] = __next_state;
            assign return_state[__STATE_OFFSET +: ELEMENT_SPEC.STATE_WID] = __return_state;
        end : g__element
    endgenerate

endmodule : state_vector
