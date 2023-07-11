module state_element_core
    import state_pkg::*;
#(
    parameter type ID_T = logic[7:0],
    parameter element_t SPEC = DEFAULT_STATE_ELEMENT,
    parameter int  NUM_WR_TRANSACTIONS = 4, // Maximum number of database write transactions that can
                                            // be in flight (from the perspective of this module)
                                            // at any given time.
    parameter int  NUM_RD_TRANSACTIONS = 8, // Maximum number of database read transactions that can
                                            // be in flight (from the perspective of this module)
                                            // at any given time.
    parameter bit  CACHE_EN = 1'b1          // Enable caching to ensure consistency of underlying state
                                            // data for cases where multiple transactions (closely spaced
                                            // in time) target the same state ID; in general, caching should
                                            // be enabled, but it can be disabled to achieve a less complex
                                            // implementation for applications insensitive to this type of inconsistency
)(
    // Clock/reset
    input  logic              clk,
    input  logic              srst,

    // Control/status
    input  logic              en,
    output logic              init_done,

    // Info interface
    db_info_intf.peripheral   info_if,

    // Update interface (from datapath)
    state_intf.target         update_if,

    // Read/update interface (from control plane)
    state_intf.target         ctrl_if,

    // Database interface (to database/storage)
    db_ctrl_intf.peripheral   db_ctrl_if,
    output logic              db_init,
    input  logic              db_init_done,
    db_intf.requester         db_wr_if,
    db_intf.requester         db_rd_if
);

    // ----------------------------------
    // Interfaces
    // ----------------------------------
    db_info_intf __info_if ();

    // ----------------------------------
    // State element is implemented as a
    // single-entry state vector
    // ----------------------------------
    localparam vector_t VECTOR_SPEC = '{
        NUM_ELEMENTS: 1,
        ELEMENTS: '{
            0 : SPEC,
            default: DEFAULT_STATE_ELEMENT
        }
    };

    state_vector_core #(
        .ID_T                ( ID_T ),
        .SPEC                ( VECTOR_SPEC ),
        .NUM_WR_TRANSACTIONS ( NUM_WR_TRANSACTIONS ),
        .NUM_RD_TRANSACTIONS ( NUM_RD_TRANSACTIONS ),
        .CACHE_EN            ( CACHE_EN )
    ) i_state_vector_core (
        .info_if ( __info_if ),
        .*
    );

    // Override subtype
    assign info_if.subtype = BLOCK_TYPE_ELEMENT;
    assign info_if._type = __info_if._type;
    assign info_if.size = __info_if.size;

endmodule : state_element_core
