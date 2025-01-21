// AXI4-L SLR crossing component
(* keep_hierarchy = "yes" *) module axi4l_pipe_slr #(
    parameter int PRE_PIPE_STAGES = 0,  // Input (pre-crossing) pipe stages, in addition to SLR-crossing stage
    parameter int POST_PIPE_STAGES = 0  // Output (post-crossing) pipe stages, in addition to SLR-crossing stage
) (
    // AXI4-L interface (from controller)
    axi4l_intf.peripheral  axi4l_if_from_controller,

    // AXI4-L interface (to peripheral)
    axi4l_intf.controller  axi4l_if_to_peripheral
);
    // Imports
    import axi4l_pkg::*;

    // Parameters
    localparam int  DATA_BYTE_WID = axi4l_if_from_controller.DATA_BYTE_WID;
    localparam type STRB_T = logic[DATA_BYTE_WID-1:0];
    localparam type DATA_T = logic[DATA_BYTE_WID-1:0][7:0];

    localparam int  ADDR_WID = axi4l_if_from_controller.ADDR_WID;
    localparam type ADDR_T = logic[ADDR_WID-1:0];

    // Payload structs
    typedef struct packed {
        logic [2:0] prot;
        ADDR_T      addr;
    } ax_payload_t;

    typedef struct packed {
        DATA_T data;
        STRB_T strb;
    } w_payload_t;

    typedef struct packed {
        resp_t resp;
    } b_payload_t;

    typedef struct packed {
        DATA_T data;
        resp_t resp;
    } r_payload_t;

    // Bus interfaces (one for each of the AXI4-L channels)
    bus_intf #(.DATA_T(ax_payload_t)) aw_bus_if__from_controller (.clk(axi4l_if_from_controller.aclk), .srst(!axi4l_if_from_controller.aresetn));
    bus_intf #(.DATA_T(ax_payload_t)) aw_bus_if__to_peripheral   (.clk(axi4l_if_from_controller.aclk), .srst(!axi4l_if_from_controller.aresetn));
    bus_intf #(.DATA_T(w_payload_t))  w_bus_if__from_controller  (.clk(axi4l_if_from_controller.aclk), .srst(!axi4l_if_from_controller.aresetn));
    bus_intf #(.DATA_T(w_payload_t))  w_bus_if__to_peripheral    (.clk(axi4l_if_from_controller.aclk), .srst(!axi4l_if_from_controller.aresetn));
    bus_intf #(.DATA_T(b_payload_t))  b_bus_if__from_controller  (.clk(axi4l_if_from_controller.aclk), .srst(!axi4l_if_from_controller.aresetn));
    bus_intf #(.DATA_T(b_payload_t))  b_bus_if__to_peripheral    (.clk(axi4l_if_from_controller.aclk), .srst(!axi4l_if_from_controller.aresetn));
    bus_intf #(.DATA_T(ax_payload_t)) ar_bus_if__from_controller (.clk(axi4l_if_from_controller.aclk), .srst(!axi4l_if_from_controller.aresetn));
    bus_intf #(.DATA_T(ax_payload_t)) ar_bus_if__to_peripheral   (.clk(axi4l_if_from_controller.aclk), .srst(!axi4l_if_from_controller.aresetn));
    bus_intf #(.DATA_T(r_payload_t))  r_bus_if__from_controller  (.clk(axi4l_if_from_controller.aclk), .srst(!axi4l_if_from_controller.aresetn));
    bus_intf #(.DATA_T(r_payload_t))  r_bus_if__to_peripheral    (.clk(axi4l_if_from_controller.aclk), .srst(!axi4l_if_from_controller.aresetn));

    axi4l_to_bus_adapter i_axi4l_to_bus_adapter (
        .axi4l_if  ( axi4l_if_from_controller ),
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

    axi4l_from_bus_adapter i_axi4l_from_bus_adapter (
        .aw_bus_if ( aw_bus_if__to_peripheral ),
        .w_bus_if  ( w_bus_if__to_peripheral ),
        .b_bus_if  ( b_bus_if__to_peripheral ),
        .ar_bus_if ( ar_bus_if__to_peripheral ),
        .r_bus_if  ( r_bus_if__to_peripheral ),
        .axi4l_if  ( axi4l_if_to_peripheral )
    );

endmodule : axi4l_pipe_slr
