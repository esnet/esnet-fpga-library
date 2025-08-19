// AXI4-L from multi-bus interface adapter
module axi4l_from_bus_adapter (
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
    localparam int  ADDR_WID = axi4l_if.ADDR_WID;
    localparam int  STRB_WID = DATA_BYTE_WID;
    localparam int  DATA_WID = DATA_BYTE_WID * 8;

    // Payload structs (opaque to underlying bus_intf infrastructure)
    typedef struct packed {
        logic [2:0] prot;
        logic [ADDR_WID-1:0] addr;
    } ax_payload_t;

    typedef struct packed {
        logic [DATA_WID-1:0] data;
        logic [STRB_WID-1:0] strb;
    } w_payload_t;

    typedef struct packed {
        resp_t resp;
    } b_payload_t;

    typedef struct packed {
        logic [DATA_WID-1:0] data;
        resp_t resp;
    } r_payload_t;

    // Parameter checking
    initial begin
        std_pkg::param_check(aw_bus_if.DATA_WID, $bits(ax_payload_t), "aw_bus_if.DATA_WID");
        std_pkg::param_check(w_bus_if.DATA_WID,  $bits(w_payload_t),  "w_bus_if.DATA_WID");
        std_pkg::param_check(ar_bus_if.DATA_WID, $bits(ax_payload_t), "ar_bus_if.DATA_WID");
        std_pkg::param_check(b_bus_if.DATA_WID,  $bits(b_payload_t),  "b_bus_if.DATA_WID");
        std_pkg::param_check(r_bus_if.DATA_WID,  $bits(r_payload_t),  "r_bus_if.DATA_WID");
    end

    // Signals
    logic clk;
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
    // -- (arbitrarily) choose this interface as the reference for clock/reset
    assign clk  = aw_bus_if.clk;
    assign srst = aw_bus_if.srst;
    assign aw_valid = aw_bus_if.valid;
    assign aw_payload = aw_bus_if.data;
    assign aw_bus_if.ready = aw_ready;

    assign w_valid = w_bus_if.valid;
    assign w_payload = w_bus_if.data;
    assign w_bus_if.ready = w_ready;

    assign b_bus_if.valid = b_valid;
    assign b_bus_if.data = b_payload;
    assign b_ready = b_bus_if.ready;

    assign ar_valid = ar_bus_if.valid;
    assign ar_payload = ar_bus_if.data;
    assign ar_bus_if.ready = ar_ready;

    assign r_bus_if.valid = r_valid;
    assign r_bus_if.data = r_payload;
    assign r_ready = r_bus_if.ready;

    // Drive AXI-L interface
    assign axi4l_if.aclk = clk;
    assign axi4l_if.aresetn = !srst;

    assign axi4l_if.awvalid = aw_valid;
    assign axi4l_if.awaddr = aw_payload.addr;
    assign axi4l_if.awprot = aw_payload.prot;
    assign aw_ready = axi4l_if.awready;

    assign axi4l_if.wvalid = w_valid;
    assign axi4l_if.wdata = w_payload.data;
    assign axi4l_if.wstrb = w_payload.strb;
    assign w_ready = axi4l_if.wready;

    assign b_valid = axi4l_if.bvalid;
    assign b_payload.resp = axi4l_if.bresp;
    assign axi4l_if.bready = b_ready;

    // Read address
    assign axi4l_if.arvalid = ar_valid;
    assign axi4l_if.araddr = ar_payload.addr;
    assign axi4l_if.arprot = ar_payload.prot;
    assign ar_ready = axi4l_if.arready;

    // Read data
    assign r_valid = axi4l_if.rvalid;
    assign r_payload.data = axi4l_if.rdata;
    assign r_payload.resp = axi4l_if.rresp;
    assign axi4l_if.rready = r_ready;

endmodule : axi4l_from_bus_adapter
