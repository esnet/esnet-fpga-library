// AXI4-L to multi-bus interface adapter
module axi4l_to_bus_adapter #(
) (
    // AXI4-L interface (from controller)
    axi4l_intf.peripheral  axi4l_if,

    // Generic bus interfaces (to peripheral)
    // -- Write address (AW) bus
    bus_intf.tx   aw_bus_if,
    // -- Write data (W) bus
    bus_intf.tx   w_bus_if,
    // -- Write response (B) bus
    bus_intf.rx   b_bus_if,
    // -- Read address (AR) bus
    bus_intf.tx   ar_bus_if,
    // -- Read data (R) bus
    bus_intf.rx   r_bus_if
);
    // Imports
    import axi4l_pkg::*;

    // Parameters
    localparam int  DATA_BYTE_WID = axi4l_if.DATA_BYTE_WID;
    localparam type STRB_T = logic[DATA_BYTE_WID-1:0];
    localparam type DATA_T = logic[DATA_BYTE_WID-1:0][7:0];

    localparam int  ADDR_WID = axi4l_if.ADDR_WID;
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

    ax_payload_t axi4l_if__aw_payload;
    w_payload_t  axi4l_if__w_payload;
    b_payload_t  axi4l_if__b_payload;
    ax_payload_t axi4l_if__ar_payload;
    r_payload_t  axi4l_if__r_payload;

    // Write address
    assign aw_bus_if.srst = !axi4l_if.aresetn;
    assign aw_bus_if.valid = axi4l_if.awvalid;
    assign axi4l_if__aw_payload.addr   = axi4l_if.awaddr;
    assign axi4l_if__aw_payload.prot   = axi4l_if.awprot;
    assign aw_bus_if.data = axi4l_if__aw_payload;
    assign axi4l_if.awready = aw_bus_if.ready;

    // Write data
    assign w_bus_if.srst = !axi4l_if.aresetn;
    assign w_bus_if.valid = axi4l_if.wvalid;
    assign axi4l_if__w_payload.data = axi4l_if.wdata;
    assign axi4l_if__w_payload.strb = axi4l_if.wstrb;
    assign w_bus_if.data = axi4l_if__w_payload;
    assign axi4l_if.wready = w_bus_if.ready;

    // Write response
    assign axi4l_if.bvalid = b_bus_if.valid;
    assign axi4l_if__b_payload = b_bus_if.data;
    assign axi4l_if.bresp = axi4l_if__b_payload.resp;
    assign b_bus_if.ready = axi4l_if.bready;

    // Read address
    assign ar_bus_if.srst = !axi4l_if.aresetn;
    assign ar_bus_if.valid = axi4l_if.arvalid;
    assign axi4l_if__ar_payload.addr   = axi4l_if.araddr;
    assign axi4l_if__ar_payload.prot   = axi4l_if.arprot;
    assign ar_bus_if.data = axi4l_if__ar_payload;
    assign axi4l_if.arready = ar_bus_if.ready;

    // Read data
    assign axi4l_if.rvalid = r_bus_if.valid;
    assign axi4l_if__r_payload = r_bus_if.data;
    assign axi4l_if.rdata = axi4l_if__r_payload.data;
    assign axi4l_if.rresp = axi4l_if__r_payload.resp;
    assign r_bus_if.ready = axi4l_if.rready;

endmodule : axi4l_to_bus_adapter
