// AXI4-L from multi-bus interface adapter
module axi4l_from_bus_adapter #(
) (
    // Generic bus interfaces (from controller)
    // Write address (AW) bus
    bus_intf.rx   aw_bus_if,
    // Write data (W) bus
    bus_intf.rx   w_bus_if,
    // Write response (B) bus
    bus_intf.tx   b_bus_if,
    // Read address (AR) bus
    bus_intf.rx   ar_bus_if,
    // Read data (R) bus
    bus_intf.tx   r_bus_if,

    // AXI4-L interface (to peripheral)
    axi4l_intf.controller  axi4l_if
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

    // Clock
    assign axi4l_if.aclk = aw_bus_if.clk;

    // Reset
    logic srst;
    assign srst = aw_bus_if.srst;

    assign axi4l_if.aresetn = !srst;

    // Write address
    assign axi4l_if.awvalid = aw_bus_if.valid;
    assign axi4l_if__aw_payload = aw_bus_if.data;
    assign axi4l_if.awaddr   = axi4l_if__aw_payload.addr;
    assign axi4l_if.awprot   = axi4l_if__aw_payload.prot;
    assign aw_bus_if.ready  = axi4l_if.awready;

    // Write data
    assign axi4l_if.wvalid = w_bus_if.valid;
    assign axi4l_if__w_payload = w_bus_if.data;
    assign axi4l_if.wdata  = axi4l_if__w_payload.data;
    assign axi4l_if.wstrb  = axi4l_if__w_payload.strb;
    assign w_bus_if.ready = axi4l_if.wready;

    // Write response
    assign b_bus_if.srst = srst;
    assign b_bus_if.valid = axi4l_if.bvalid;
    assign axi4l_if__b_payload.resp = axi4l_if.bresp;
    assign b_bus_if.data = axi4l_if__b_payload;
    assign axi4l_if.bready = b_bus_if.ready;

    // Read address
    assign axi4l_if.arvalid = ar_bus_if.valid;
    assign axi4l_if__ar_payload = ar_bus_if.data;
    assign axi4l_if.araddr   = axi4l_if__ar_payload.addr;
    assign axi4l_if.arprot   = axi4l_if__ar_payload.prot;
    assign ar_bus_if.ready  = axi4l_if.arready;

    // Read data
    assign r_bus_if.srst = srst;
    assign r_bus_if.valid = axi4l_if.rvalid;
    assign axi4l_if__r_payload.data = axi4l_if.rdata;
    assign axi4l_if__r_payload.resp = axi4l_if.rresp;
    assign r_bus_if.data = axi4l_if__r_payload;
    assign axi4l_if.rready = r_bus_if.ready;

endmodule : axi4l_from_bus_adapter
