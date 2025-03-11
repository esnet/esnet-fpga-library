// AXI3 to multi-bus interface adapter
module axi3_to_bus_adapter #(
) (
    // AXI3 interface (from controller)
    axi3_intf.peripheral  axi3_if,

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

    // Write address
    assign aw_bus_if.srst = !axi3_if.aresetn;
    assign aw_bus_if.valid = axi3_if.awvalid;
    assign axi3_if__aw_payload.id     = axi3_if.awid;
    assign axi3_if__aw_payload.addr   = axi3_if.awaddr;
    assign axi3_if__aw_payload.len    = axi3_if.awlen;
    assign axi3_if__aw_payload.size   = axi3_if.awsize;
    assign axi3_if__aw_payload.burst  = axi3_if.awburst;
    assign axi3_if__aw_payload.lock   = axi3_if.awlock;
    assign axi3_if__aw_payload.cache  = axi3_if.awcache;
    assign axi3_if__aw_payload.prot   = axi3_if.awprot;
    assign axi3_if__aw_payload.qos    = axi3_if.awqos;
    assign axi3_if__aw_payload.region = axi3_if.awregion;
    assign axi3_if__aw_payload.user   = axi3_if.awuser;
    assign aw_bus_if.data = axi3_if__aw_payload;
    assign axi3_if.awready = aw_bus_if.ready;

    // Write data
    assign w_bus_if.srst = !axi3_if.aresetn;
    assign w_bus_if.valid = axi3_if.wvalid;
    assign axi3_if__w_payload.id   = axi3_if.wid;
    assign axi3_if__w_payload.data = axi3_if.wdata;
    assign axi3_if__w_payload.strb = axi3_if.wstrb;
    assign axi3_if__w_payload.last = axi3_if.wlast;
    assign axi3_if__w_payload.user = axi3_if.wuser;
    assign w_bus_if.data = axi3_if__w_payload;
    assign axi3_if.wready = w_bus_if.ready;

    // Write response
    assign axi3_if.bvalid = b_bus_if.valid;
    assign axi3_if__b_payload = b_bus_if.data;
    assign axi3_if.bid   = axi3_if__b_payload.id;
    assign axi3_if.bresp = axi3_if__b_payload.resp;
    assign axi3_if.buser = axi3_if__b_payload.user;
    assign b_bus_if.ready = axi3_if.bready;

    // Read address
    assign ar_bus_if.srst = !axi3_if.aresetn;
    assign ar_bus_if.valid = axi3_if.arvalid;
    assign axi3_if__ar_payload.id     = axi3_if.arid;
    assign axi3_if__ar_payload.addr   = axi3_if.araddr;
    assign axi3_if__ar_payload.len    = axi3_if.arlen;
    assign axi3_if__ar_payload.size   = axi3_if.arsize;
    assign axi3_if__ar_payload.burst  = axi3_if.arburst;
    assign axi3_if__ar_payload.lock   = axi3_if.arlock;
    assign axi3_if__ar_payload.cache  = axi3_if.arcache;
    assign axi3_if__ar_payload.prot   = axi3_if.arprot;
    assign axi3_if__ar_payload.qos    = axi3_if.arqos;
    assign axi3_if__ar_payload.region = axi3_if.arregion;
    assign axi3_if__ar_payload.user   = axi3_if.aruser;
    assign ar_bus_if.data = axi3_if__ar_payload;
    assign axi3_if.arready = ar_bus_if.ready;

    // Read data
    assign axi3_if.rvalid = r_bus_if.valid;
    assign axi3_if__r_payload = r_bus_if.data;
    assign axi3_if.rid   = axi3_if__r_payload.id;
    assign axi3_if.rdata = axi3_if__r_payload.data;
    assign axi3_if.rresp = axi3_if__r_payload.resp;
    assign axi3_if.rlast = axi3_if__r_payload.last;
    assign axi3_if.ruser = axi3_if__r_payload.user;
    assign r_bus_if.ready = axi3_if.rready;

endmodule : axi3_to_bus_adapter
