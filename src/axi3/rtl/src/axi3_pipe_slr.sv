// AXI3 SLR crossing component
(* keep_hierarchy = "yes" *) module axi3_pipe_slr #(
    parameter int PRE_PIPE_STAGES = 0,  // Input (pre-crossing) pipe stages, in addition to SLR-crossing stage
    parameter int POST_PIPE_STAGES = 0  // Output (post-crossing) pipe stages, in addition to SLR-crossing stage
) (
    // AXI3 interface (from controller)
    axi3_intf.peripheral  axi3_if_from_controller,

    // AXI3 interface (to peripheral)
    axi3_intf.controller  axi3_if_to_peripheral
);
    // Imports
    import axi3_pkg::*;

    // Parameters
    localparam int  DATA_BYTE_WID = axi3_if_from_controller.DATA_BYTE_WID;
    localparam type STRB_T = logic[DATA_BYTE_WID-1:0];
    localparam type DATA_T = logic[DATA_BYTE_WID-1:0][7:0];

    localparam int  ADDR_WID = axi3_if_from_controller.ADDR_WID;
    localparam type ADDR_T = logic[ADDR_WID-1:0];

    localparam int  ID_WID = $bits(axi3_if_from_controller.ID_T);
    localparam type ID_T = logic[ID_WID-1:0];

    localparam int  USER_WID = $bits(axi3_if_from_controller.USER_T);
    localparam type USER_T = logic[USER_WID-1:0];

    // Payload structs
    typedef struct packed {
        ID_T        id;
        ADDR_T      addr;
        logic [3:0] len;
        axsize_t    size;
        axburst_t   burst;
        axlock_t    lock;
        axcache_t   cache;
        axprot_t    prot;
        logic [3:0] qos;
        logic [3:0] region;
        USER_T      user;
    } ax_payload_t;

    typedef struct packed {
        ID_T   id;
        DATA_T data;
        STRB_T strb;
        logic  last;
        USER_T user;
    } w_payload_t;

    typedef struct packed {
        ID_T   id;
        resp_t resp;
        USER_T user;
    } b_payload_t;

    typedef struct packed {
        ID_T   id;
        DATA_T data;
        resp_t resp;
        logic  last;
        USER_T user;
    } r_payload_t;

    // Bus interfaces (one for each of the AXI3 channels)
    bus_intf #(.DATA_T(ax_payload_t)) aw_bus_if__from_controller (.clk(axi3_if_from_controller.aclk));
    bus_intf #(.DATA_T(ax_payload_t)) aw_bus_if__to_peripheral   (.clk(axi3_if_from_controller.aclk));
    bus_intf #(.DATA_T(w_payload_t))  w_bus_if__from_controller  (.clk(axi3_if_from_controller.aclk));
    bus_intf #(.DATA_T(w_payload_t))  w_bus_if__to_peripheral    (.clk(axi3_if_from_controller.aclk));
    bus_intf #(.DATA_T(b_payload_t))  b_bus_if__from_controller  (.clk(axi3_if_from_controller.aclk));
    bus_intf #(.DATA_T(b_payload_t))  b_bus_if__to_peripheral    (.clk(axi3_if_from_controller.aclk));
    bus_intf #(.DATA_T(ax_payload_t)) ar_bus_if__from_controller (.clk(axi3_if_from_controller.aclk));
    bus_intf #(.DATA_T(ax_payload_t)) ar_bus_if__to_peripheral   (.clk(axi3_if_from_controller.aclk));
    bus_intf #(.DATA_T(r_payload_t))  r_bus_if__from_controller  (.clk(axi3_if_from_controller.aclk));
    bus_intf #(.DATA_T(r_payload_t))  r_bus_if__to_peripheral    (.clk(axi3_if_from_controller.aclk));

    axi3_to_bus_adapter i_axi3_to_bus_adapter (
        .axi3_if   ( axi3_if_from_controller ),
        .aw_bus_if ( aw_bus_if__from_controller ),
        .w_bus_if  ( w_bus_if__from_controller ),
        .b_bus_if  ( b_bus_if__from_controller ),
        .ar_bus_if ( ar_bus_if__from_controller ),
        .r_bus_if  ( r_bus_if__from_controller )
    );

    generate
        begin : g__fwd
            bus_pipe_slr #(0, PRE_PIPE_STAGES, POST_PIPE_STAGES) i_bus_pipe_slr__aw ( .bus_if_from_tx ( aw_bus_if__from_controller ), .bus_if_to_rx ( aw_bus_if__to_peripheral ));
            bus_pipe_slr #(0, PRE_PIPE_STAGES, POST_PIPE_STAGES) i_bus_pipe_slr__w  ( .bus_if_from_tx ( w_bus_if__from_controller ),  .bus_if_to_rx ( w_bus_if__to_peripheral ));
            bus_pipe_slr #(0, PRE_PIPE_STAGES, POST_PIPE_STAGES) i_bus_pipe_slr__ar ( .bus_if_from_tx ( ar_bus_if__from_controller ), .bus_if_to_rx ( ar_bus_if__to_peripheral ));
        end : g__fwd
        begin : g__rev
            bus_pipe_slr #(0, PRE_PIPE_STAGES, POST_PIPE_STAGES) i_bus_pipe_slr__b  ( .bus_if_from_tx ( b_bus_if__to_peripheral ),  .bus_if_to_rx ( b_bus_if__from_controller ));
            bus_pipe_slr #(0, PRE_PIPE_STAGES, POST_PIPE_STAGES) i_bus_pipe_slr__r  ( .bus_if_from_tx ( r_bus_if__to_peripheral ),  .bus_if_to_rx ( r_bus_if__from_controller ));
        end : g__rev
    endgenerate

    axi3_from_bus_adapter i_axi3_from_bus_adapter (
        .aw_bus_if ( aw_bus_if__to_peripheral ),
        .w_bus_if  ( w_bus_if__to_peripheral ),
        .b_bus_if  ( b_bus_if__to_peripheral ),
        .ar_bus_if ( ar_bus_if__to_peripheral ),
        .r_bus_if  ( r_bus_if__to_peripheral ),
        .axi3_if   ( axi3_if_to_peripheral )
    );

endmodule : axi3_pipe_slr
