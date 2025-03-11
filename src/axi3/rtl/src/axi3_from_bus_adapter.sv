// AXI3 from multi-bus interface adapter
module axi3_from_bus_adapter #(
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

    // AXI3 interface (to peripheral)
    axi3_intf.controller  axi3_if
);
    // Imports
    import axi3_pkg::*;

    // Parameters
    localparam int  DATA_BYTE_WID = axi3_if.DATA_BYTE_WID;
    localparam type STRB_T = logic[DATA_BYTE_WID-1:0];
    localparam type DATA_T = logic[DATA_BYTE_WID-1:0][7:0];

    localparam int  ADDR_WID = axi3_if.ADDR_WID;
    localparam type ADDR_T = logic[ADDR_WID-1:0];

    localparam int  ID_WID = $bits(axi3_if.ID_T);
    localparam type ID_T = logic[ID_WID-1:0];

    localparam int  USER_WID = $bits(axi3_if.USER_T);
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

    ax_payload_t axi3_if__aw_payload;
    w_payload_t  axi3_if__w_payload;
    b_payload_t  axi3_if__b_payload;
    ax_payload_t axi3_if__ar_payload;
    r_payload_t  axi3_if__r_payload;

    // Reset
    logic srst;
    assign srst = aw_bus_if.srst;

    assign axi3_if.aresetn = !srst;

    // Write address
    assign axi3_if.awvalid = aw_bus_if.valid;
    assign axi3_if__aw_payload = aw_bus_if.data;
    assign axi3_if.awid     = axi3_if__aw_payload.id;
    assign axi3_if.awaddr   = axi3_if__aw_payload.addr;
    assign axi3_if.awlen    = axi3_if__aw_payload.len;
    assign axi3_if.awsize   = axi3_if__aw_payload.size;
    assign axi3_if.awburst  = axi3_if__aw_payload.burst;
    assign axi3_if.awlock   = axi3_if__aw_payload.lock;
    assign axi3_if.awcache  = axi3_if__aw_payload.cache;
    assign axi3_if.awprot   = axi3_if__aw_payload.prot;
    assign axi3_if.awqos    = axi3_if__aw_payload.qos;
    assign axi3_if.awregion = axi3_if__aw_payload.region;
    assign axi3_if.awuser   = axi3_if__aw_payload.user;
    assign aw_bus_if.ready  = axi3_if.awready;

    // Write data
    assign axi3_if.wvalid = w_bus_if.valid;
    assign axi3_if__w_payload = w_bus_if.data;
    assign axi3_if.wid    = axi3_if__w_payload.id;
    assign axi3_if.wdata  = axi3_if__w_payload.data;
    assign axi3_if.wstrb  = axi3_if__w_payload.strb;
    assign axi3_if.wlast  = axi3_if__w_payload.last;
    assign axi3_if.wuser  = axi3_if__w_payload.user;
    assign w_bus_if.ready = axi3_if.wready;

    // Write response
    assign b_bus_if.srst = srst;
    assign b_bus_if.valid = axi3_if.bvalid;
    assign axi3_if__b_payload.id   = axi3_if.bid;
    assign axi3_if__b_payload.resp = axi3_if.bresp;
    assign axi3_if__b_payload.user = axi3_if.buser;
    assign b_bus_if.data = axi3_if__b_payload;
    assign axi3_if.bready = b_bus_if.ready;

    // Read address
    assign axi3_if.arvalid = ar_bus_if.valid;
    assign axi3_if__ar_payload = ar_bus_if.data;
    assign axi3_if.arid     = axi3_if__ar_payload.id;
    assign axi3_if.araddr   = axi3_if__ar_payload.addr;
    assign axi3_if.arlen    = axi3_if__ar_payload.len;
    assign axi3_if.arsize   = axi3_if__ar_payload.size;
    assign axi3_if.arburst  = axi3_if__ar_payload.burst;
    assign axi3_if.arlock   = axi3_if__ar_payload.lock;
    assign axi3_if.arcache  = axi3_if__ar_payload.cache;
    assign axi3_if.arprot   = axi3_if__ar_payload.prot;
    assign axi3_if.arqos    = axi3_if__ar_payload.qos;
    assign axi3_if.arregion = axi3_if__ar_payload.region;
    assign axi3_if.aruser   = axi3_if__ar_payload.user;
    assign ar_bus_if.ready  = axi3_if.arready;

    // Read data
    assign r_bus_if.srst = srst;
    assign r_bus_if.valid = axi3_if.rvalid;
    assign axi3_if__r_payload.id   = axi3_if.rid;
    assign axi3_if__r_payload.data = axi3_if.rdata;
    assign axi3_if__r_payload.resp = axi3_if.rresp;
    assign axi3_if__r_payload.last = axi3_if.rlast;
    assign axi3_if__r_payload.user = axi3_if.ruser;
    assign r_bus_if.data = axi3_if__r_payload;
    assign axi3_if.rready = r_bus_if.ready;

endmodule : axi3_from_bus_adapter
