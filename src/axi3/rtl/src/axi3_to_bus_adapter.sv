// AXI3 to multi-bus interface adapter
module axi3_to_bus_adapter (
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

    // Terminate AXI3 interface
    assign srst = !axi3_if.aresetn;
    
    assign aw_valid = axi3_if.awvalid;
    assign aw_payload.id     = axi3_if.awid;
    assign aw_payload.addr   = axi3_if.awaddr;
    assign aw_payload.len    = axi3_if.awlen;
    assign aw_payload.size   = axi3_if.awsize;
    assign aw_payload.burst  = axi3_if.awburst;
    assign aw_payload.lock   = axi3_if.awlock;
    assign aw_payload.cache  = axi3_if.awcache;
    assign aw_payload.prot   = axi3_if.awprot;
    assign aw_payload.qos    = axi3_if.awqos;
    assign aw_payload.region = axi3_if.awregion;
    assign aw_payload.user   = axi3_if.awuser;
    assign axi3_if.awready = aw_ready;
 
    assign w_valid = axi3_if.wvalid;
    assign w_payload.id   = axi3_if.wid;
    assign w_payload.data = axi3_if.wdata;
    assign w_payload.strb = axi3_if.wstrb;
    assign w_payload.last = axi3_if.wlast;
    assign w_payload.user = axi3_if.wuser;
    assign axi3_if.wready = w_ready;
 
    assign axi3_if.bvalid = b_valid;
    assign axi3_if.bid   = b_payload.id;
    assign axi3_if.bresp = b_payload.resp;
    assign axi3_if.buser = b_payload.user;
    assign b_ready = axi3_if.bready;

    assign ar_valid = axi3_if.arvalid;
    assign ar_payload.id     = axi3_if.arid;
    assign ar_payload.addr   = axi3_if.araddr;
    assign ar_payload.len    = axi3_if.arlen;
    assign ar_payload.size   = axi3_if.arsize;
    assign ar_payload.burst  = axi3_if.arburst;
    assign ar_payload.lock   = axi3_if.arlock;
    assign ar_payload.cache  = axi3_if.arcache;
    assign ar_payload.prot   = axi3_if.arprot;
    assign ar_payload.qos    = axi3_if.arqos;
    assign ar_payload.region = axi3_if.arregion;
    assign ar_payload.user   = axi3_if.aruser;
    assign axi3_if.arready = ar_ready;
 
    assign axi3_if.rvalid = r_valid;
    assign axi3_if.rid   = r_payload.id;
    assign axi3_if.rdata = r_payload.data;
    assign axi3_if.rresp = r_payload.resp;
    assign axi3_if.rlast = r_payload.last;
    assign axi3_if.ruser = r_payload.user;
    assign r_ready = axi3_if.rready;

    // Write address
    assign aw_bus_if.srst = srst;
    assign aw_bus_if.valid = aw_valid;
    assign aw_bus_if.data = aw_payload;
    assign aw_ready = aw_bus_if.ready;

    // Write data
    assign w_bus_if.srst = srst;
    assign w_bus_if.valid = w_valid;
    assign w_bus_if.data = w_payload;
    assign w_ready = w_bus_if.ready;

    // Write response
    assign b_valid = b_bus_if.valid;
    assign b_payload = b_bus_if.data;
    assign b_bus_if.ready = b_ready;

    // Read address
    assign ar_bus_if.srst = srst;
    assign ar_bus_if.valid = ar_valid;
    assign ar_bus_if.data = ar_payload;
    assign ar_ready = ar_bus_if.ready;

    // Read data
    assign r_valid = r_bus_if.valid;
    assign r_payload = r_bus_if.data;
    assign r_bus_if.ready = r_ready;

endmodule : axi3_to_bus_adapter
