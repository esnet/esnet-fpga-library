// AXI3 from multi-bus interface adapter
module axi3_from_bus_adapter (
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
    localparam int DATA_BYTE_WID = axi3_if.DATA_BYTE_WID;
    localparam int DATA_WID = DATA_BYTE_WID*8;
    localparam int STRB_WID = DATA_BYTE_WID;
    localparam int ADDR_WID = axi3_if.ADDR_WID;
    localparam int ID_WID   = $bits(axi3_if.ID_T);
    localparam int USER_WID = $bits(axi3_if.USER_T);

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
        std_pkg::param_check($bits(aw_bus_if.DATA_T), $bits(ax_payload_t), "aw_bus_if.DATA_T");
        std_pkg::param_check($bits(w_bus_if.DATA_T),  $bits(w_payload_t),  "w_bus_if.DATA_T");
        std_pkg::param_check($bits(ar_bus_if.DATA_T), $bits(ax_payload_t), "ar_bus_if.DATA_T");
        std_pkg::param_check($bits(b_bus_if.DATA_T),  $bits(b_payload_t),  "b_bus_if.DATA_T");
        std_pkg::param_check($bits(r_bus_if.DATA_T),  $bits(r_payload_t),  "r_bus_if.DATA_T");
    end

    // Signals
    logic srst;

    logic        aw_valid;
    ax_payload_t aw_payload;
    logic        aw_ready;

    logic        w_valid;
    w_payload_t  w_payload;
    logic        w_ready;

    logic        b_valid;
    b_payload_t  b_payload;
    logic        b_ready;

    logic        ar_valid;
    ax_payload_t ar_payload;
    logic        ar_ready;

    logic        r_valid;
    r_payload_t  r_payload;
    logic        r_ready;

    // Terminate write address bus interface
    // -- (arbitrarily) choose this interface as the reference for reset
    assign srst = aw_bus_if.srst;
    assign aw_valid = aw_bus_if.valid;
    assign aw_payload = aw_bus_if.data;
    assign aw_bus_if.ready = aw_ready;

    // Terminate write data bus interface
    assign w_valid = w_bus_if.valid;
    assign w_payload = w_bus_if.data;
    assign w_bus_if.ready = w_ready;

    // Terminate write response bus interface
    assign b_bus_if.srst = srst;
    assign b_bus_if.valid = b_valid;
    assign b_bus_if.data = b_payload;
    assign b_ready = b_bus_if.ready;

    // Terminate read address bus interface
    assign ar_valid = ar_bus_if.valid;
    assign ar_payload = ar_bus_if.data;
    assign ar_bus_if.ready = ar_ready;

    // Terminate read data bus interface
    assign r_bus_if.srst = srst;
    assign r_bus_if.valid = r_valid;
    assign r_bus_if.data = r_payload;
    assign r_ready = r_bus_if.ready;

    // Drive AXI3 interface
    assign axi3_if.aresetn = !srst;

    assign axi3_if.awvalid = aw_valid;
    assign axi3_if.awid     = aw_payload.id;
    assign axi3_if.awaddr   = aw_payload.addr;
    assign axi3_if.awlen    = aw_payload.len;
    assign axi3_if.awsize   = aw_payload.size;
    assign axi3_if.awburst  = aw_payload.burst;
    assign axi3_if.awlock   = aw_payload.lock;
    assign axi3_if.awcache  = aw_payload.cache;
    assign axi3_if.awprot   = aw_payload.prot;
    assign axi3_if.awqos    = aw_payload.qos;
    assign axi3_if.awregion = aw_payload.region;
    assign axi3_if.awuser   = aw_payload.user;
    assign aw_ready = axi3_if.awready;

    assign axi3_if.wvalid = w_valid;
    assign axi3_if.wid    = w_payload.id;
    assign axi3_if.wdata  = w_payload.data;
    assign axi3_if.wstrb  = w_payload.strb;
    assign axi3_if.wlast  = w_payload.last;
    assign axi3_if.wuser  = w_payload.user;
    assign w_ready = axi3_if.wready;

    assign b_valid = axi3_if.bvalid;
    assign b_payload.id   = axi3_if.bid;
    assign b_payload.resp = axi3_if.bresp;
    assign b_payload.user = axi3_if.buser;
    assign axi3_if.bready = b_ready;

    assign axi3_if.arvalid = ar_valid;
    assign axi3_if.arid     = ar_payload.id;
    assign axi3_if.araddr   = ar_payload.addr;
    assign axi3_if.arlen    = ar_payload.len;
    assign axi3_if.arsize   = ar_payload.size;
    assign axi3_if.arburst  = ar_payload.burst;
    assign axi3_if.arlock   = ar_payload.lock;
    assign axi3_if.arcache  = ar_payload.cache;
    assign axi3_if.arprot   = ar_payload.prot;
    assign axi3_if.arqos    = ar_payload.qos;
    assign axi3_if.arregion = ar_payload.region;
    assign axi3_if.aruser   = ar_payload.user;
    assign ar_ready = axi3_if.arready;

    assign r_valid = axi3_if.rvalid;
    assign r_payload.id   = axi3_if.rid;
    assign r_payload.data = axi3_if.rdata;
    assign r_payload.resp = axi3_if.rresp;
    assign r_payload.last = axi3_if.rlast;
    assign r_payload.user = axi3_if.ruser;
    assign axi3_if.rready = r_ready;

endmodule : axi3_from_bus_adapter
