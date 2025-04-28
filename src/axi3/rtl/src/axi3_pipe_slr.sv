// AXI3 SLR crossing component
(* keep_hierarchy = "yes" *) module axi3_pipe_slr #(
    parameter int PRE_PIPE_STAGES = 0,  // Input (pre-crossing) pipe stages, in addition to SLR-crossing stage
    parameter int POST_PIPE_STAGES = 0  // Output (post-crossing) pipe stages, in addition to SLR-crossing stage
) (
    // AXI3 interface (from controller)
    axi3_intf.peripheral  from_controller,

    // AXI3 interface (to peripheral)
    axi3_intf.controller  to_peripheral
);
    // Imports
    import axi3_pkg::*;

    // Parameters
    localparam int DATA_BYTE_WID = from_controller.DATA_BYTE_WID;
    localparam int DATA_WID = DATA_BYTE_WID*8;
    localparam int STRB_WID = DATA_BYTE_WID;
    localparam int ADDR_WID = from_controller.ADDR_WID;
    localparam int ID_WID   = $bits(from_controller.ID_T);
    localparam int USER_WID = $bits(from_controller.USER_T);

    // Payload structs
    typedef struct packed {
        logic [ID_WID-1:0]   id;
        logic [ADDR_WID-1:0] addr;
        logic [3:0]          len;
        axsize_t             size;
        axburst_t            burst;
        axlock_t             lock;
        axcache_t            cache;
        axprot_t             prot;
        logic [3:0]          qos;
        logic [3:0]          region;
        logic [USER_WID-1:0] user;
    } ax_payload_t;

    typedef struct packed {
        logic [ID_WID-1:0]   id;
        logic [DATA_WID-1:0] data;
        logic [STRB_WID-1:0] strb;
        logic                last;
        logic [USER_WID-1:0] user;
    } w_payload_t;

    typedef struct packed {
        logic [ID_WID-1:0]   id;
        resp_t               resp;
        logic [USER_WID-1:0] user;
    } b_payload_t;

    typedef struct packed {
        logic [ID_WID-1:0]   id;
        logic [DATA_WID-1:0] data;
        resp_t               resp;
        logic                last;
        logic [USER_WID-1:0] user;
    } r_payload_t;

    // Parameter checking
    initial begin
        std_pkg::param_check(to_peripheral.DATA_BYTE_WID,   DATA_BYTE_WID, "to_peripheral.DATA_BYTE_WID");
        std_pkg::param_check(to_peripheral.ADDR_WID,        ADDR_WID,      "to_peripheral.ADDR_WID");
        std_pkg::param_check($bits(to_peripheral.ID_T),     ID_WID,        "to_peripheral.ID_WID");
        std_pkg::param_check($bits(to_peripheral.USER_T),   USER_WID,      "to_peripheral.USER_WID");
    end

    // Signals
    logic clk;
    assign clk = from_controller.aclk;

    // Bus interfaces (one for each of the AXI3 channels)
    bus_intf #(.DATA_T(ax_payload_t)) aw_bus_if__from_controller (.clk);
    bus_intf #(.DATA_T(w_payload_t))  w_bus_if__from_controller  (.clk);
    bus_intf #(.DATA_T(b_payload_t))  b_bus_if__from_controller  (.clk);
    bus_intf #(.DATA_T(ax_payload_t)) ar_bus_if__from_controller (.clk);
    bus_intf #(.DATA_T(r_payload_t))  r_bus_if__from_controller  (.clk);
    bus_intf #(.DATA_T(ax_payload_t)) aw_bus_if__to_peripheral   (.clk);
    bus_intf #(.DATA_T(w_payload_t))  w_bus_if__to_peripheral    (.clk);
    bus_intf #(.DATA_T(b_payload_t))  b_bus_if__to_peripheral    (.clk);
    bus_intf #(.DATA_T(ax_payload_t)) ar_bus_if__to_peripheral   (.clk);
    bus_intf #(.DATA_T(r_payload_t))  r_bus_if__to_peripheral    (.clk);

    axi3_to_bus_adapter i_axi3_to_bus_adapter (
        .axi3_if   ( from_controller ),
        .aw_bus_if ( aw_bus_if__from_controller ),
        .w_bus_if  ( w_bus_if__from_controller ),
        .b_bus_if  ( b_bus_if__from_controller ),
        .ar_bus_if ( ar_bus_if__from_controller ),
        .r_bus_if  ( r_bus_if__from_controller )
    );

    generate
        begin : g__fwd
            bus_pipe_slr #(.DATA_T(ax_payload_t), .PRE_PIPE_STAGES(PRE_PIPE_STAGES), .POST_PIPE_STAGES(POST_PIPE_STAGES)) i_bus_pipe_slr__aw ( .from_tx ( aw_bus_if__from_controller ), .to_rx ( aw_bus_if__to_peripheral ));
            bus_pipe_slr #(.DATA_T(w_payload_t),  .PRE_PIPE_STAGES(PRE_PIPE_STAGES), .POST_PIPE_STAGES(POST_PIPE_STAGES)) i_bus_pipe_slr__w  ( .from_tx ( w_bus_if__from_controller ),  .to_rx ( w_bus_if__to_peripheral ));
            bus_pipe_slr #(.DATA_T(ax_payload_t), .PRE_PIPE_STAGES(PRE_PIPE_STAGES), .POST_PIPE_STAGES(POST_PIPE_STAGES)) i_bus_pipe_slr__ar ( .from_tx ( ar_bus_if__from_controller ), .to_rx ( ar_bus_if__to_peripheral ));
        end : g__fwd
        begin : g__rev
            bus_pipe_slr #(.DATA_T(b_payload_t),  .PRE_PIPE_STAGES(PRE_PIPE_STAGES), .POST_PIPE_STAGES(POST_PIPE_STAGES)) i_bus_pipe_slr__b  ( .from_tx ( b_bus_if__to_peripheral ),  .to_rx ( b_bus_if__from_controller ));
            bus_pipe_slr #(.DATA_T(r_payload_t),  .PRE_PIPE_STAGES(PRE_PIPE_STAGES), .POST_PIPE_STAGES(POST_PIPE_STAGES)) i_bus_pipe_slr__r  ( .from_tx ( r_bus_if__to_peripheral ),  .to_rx ( r_bus_if__from_controller ));
        end : g__rev
    endgenerate

    axi3_from_bus_adapter i_axi3_from_bus_adapter (
        .aw_bus_if ( aw_bus_if__to_peripheral ),
        .w_bus_if  ( w_bus_if__to_peripheral ),
        .b_bus_if  ( b_bus_if__to_peripheral ),
        .ar_bus_if ( ar_bus_if__to_peripheral ),
        .r_bus_if  ( r_bus_if__to_peripheral ),
        .axi3_if   ( to_peripheral )
    );

endmodule : axi3_pipe_slr
