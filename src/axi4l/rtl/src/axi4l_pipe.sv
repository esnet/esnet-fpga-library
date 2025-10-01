// AXI4-L pipeline
//
// Pipelines each of the constituent AXI4-L channels, in both directions (valid + ready) 
module axi4l_pipe #(
    parameter int STAGES = 1 // Pipeline stages, inserted in both forward (valid) and reverse (ready) directions
) (
    // AXI4-L interface (from controller)
    axi4l_intf.peripheral  from_controller,

    // AXI4-L interface (to peripheral)
    axi4l_intf.controller  to_peripheral
);
    // Imports
    import axi4l_pkg::*;

    // Parameters
    localparam int  DATA_BYTE_WID = from_controller.DATA_BYTE_WID;
    localparam int  ADDR_WID = from_controller.ADDR_WID;
    localparam int  STRB_WID = DATA_BYTE_WID;
    localparam int  DATA_WID = DATA_BYTE_WID * 8;

    // Payload structs (opaque to underlying bus_intf infrastructure)
    typedef struct packed {
        logic [2:0] prot;
        logic [ADDR_WID-1:0] addr;
    } ax_payload_t;
    localparam AX_PAYLOAD_WID = $bits(ax_payload_t);

    typedef struct packed {
        logic [DATA_WID-1:0] data;
        logic [STRB_WID-1:0] strb;
    } w_payload_t;
    localparam W_PAYLOAD_WID = $bits(w_payload_t);

    typedef struct packed {
        resp_t resp;
    } b_payload_t;
    localparam B_PAYLOAD_WID = $bits(b_payload_t);

    typedef struct packed {
        logic [DATA_WID-1:0] data;
        resp_t resp;
    } r_payload_t;
    localparam R_PAYLOAD_WID = $bits(r_payload_t);

    // Parameter checking
    initial begin
        std_pkg::param_check(from_controller.DATA_BYTE_WID, DATA_BYTE_WID, "from_controller.DATA_BYTE_WID");
        std_pkg::param_check(from_controller.ADDR_WID,      ADDR_WID,      "from_controller.ADDR_WID");
        std_pkg::param_check(to_peripheral.DATA_BYTE_WID,   DATA_BYTE_WID, "to_peripheral.DATA_BYTE_WID");
        std_pkg::param_check(to_peripheral.ADDR_WID,        ADDR_WID,      "to_peripheral.ADDR_WID");
    end

    // Signals
    logic clk;
    logic srst;

    assign clk = from_controller.aclk;
    assign srst = !from_controller.aresetn;

    // Bus interfaces (one for each of the AXI4-L channels)
    bus_intf #(.DATA_WID(AX_PAYLOAD_WID)) aw_bus_if__from_controller (.clk);
    bus_intf #(.DATA_WID(AX_PAYLOAD_WID)) aw_bus_if__to_peripheral   (.clk);
    bus_intf #(.DATA_WID(W_PAYLOAD_WID))  w_bus_if__from_controller  (.clk);
    bus_intf #(.DATA_WID(W_PAYLOAD_WID))  w_bus_if__to_peripheral    (.clk);
    bus_intf #(.DATA_WID(B_PAYLOAD_WID))  b_bus_if__from_controller  (.clk);
    bus_intf #(.DATA_WID(B_PAYLOAD_WID))  b_bus_if__to_peripheral    (.clk);
    bus_intf #(.DATA_WID(AX_PAYLOAD_WID)) ar_bus_if__from_controller (.clk);
    bus_intf #(.DATA_WID(AX_PAYLOAD_WID)) ar_bus_if__to_peripheral   (.clk);
    bus_intf #(.DATA_WID(R_PAYLOAD_WID))  r_bus_if__from_controller  (.clk);
    bus_intf #(.DATA_WID(R_PAYLOAD_WID))  r_bus_if__to_peripheral    (.clk);

    axi4l_to_bus_adapter i_axi4l_to_bus_adapter (
        .axi4l_if  ( from_controller ),
        .aw_bus_if ( aw_bus_if__from_controller ),
        .w_bus_if  ( w_bus_if__from_controller ),
        .b_bus_if  ( b_bus_if__from_controller ),
        .ar_bus_if ( ar_bus_if__from_controller ),
        .r_bus_if  ( r_bus_if__from_controller )
    );

    generate
        begin : g__fwd
            bus_pipe #(.STAGES(STAGES)) i_bus_pipe__aw (.srst, .from_tx (aw_bus_if__from_controller), .to_rx (aw_bus_if__to_peripheral));
            bus_pipe #(.STAGES(STAGES)) i_bus_pipe__w  (.srst, .from_tx (w_bus_if__from_controller),  .to_rx (w_bus_if__to_peripheral));
            bus_pipe #(.STAGES(STAGES)) i_bus_pipe__ar (.srst, .from_tx (ar_bus_if__from_controller), .to_rx (ar_bus_if__to_peripheral));
        end : g__fwd
        begin : g__rev
            bus_pipe #(.STAGES(STAGES)) i_bus_pipe__b  (.srst, .from_tx (b_bus_if__to_peripheral), .to_rx (b_bus_if__from_controller));
            bus_pipe #(.STAGES(STAGES)) i_bus_pipe__r  (.srst, .from_tx (r_bus_if__to_peripheral), .to_rx (r_bus_if__from_controller));
        end : g__rev
    endgenerate

    axi4l_from_bus_adapter i_axi4l_from_bus_adapter (
        .aresetn   ( from_controller.aresetn ),
        .aw_bus_if ( aw_bus_if__to_peripheral ),
        .w_bus_if  ( w_bus_if__to_peripheral ),
        .b_bus_if  ( b_bus_if__to_peripheral ),
        .ar_bus_if ( ar_bus_if__to_peripheral ),
        .r_bus_if  ( r_bus_if__to_peripheral ),
        .axi4l_if  ( to_peripheral )
    );

endmodule : axi4l_pipe
