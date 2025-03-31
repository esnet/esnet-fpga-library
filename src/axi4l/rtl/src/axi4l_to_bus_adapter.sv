// AXI4-L to multi-bus interface adapter
module axi4l_to_bus_adapter (
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

    // Terminate AXI-L interface
    assign srst = !axi4l_if.aresetn;
    
    assign aw_valid = axi4l_if.awvalid;
    assign aw_payload.addr = axi4l_if.awaddr;
    assign aw_payload.prot = axi4l_if.awprot;
    assign axi4l_if.awready = aw_ready;

    assign w_valid = axi4l_if.wvalid;
    assign w_payload.data = axi4l_if.wdata;
    assign w_payload.strb = axi4l_if.wstrb;
    assign axi4l_if.wready = w_ready;
 
    assign axi4l_if.bvalid = b_valid;
    assign axi4l_if.bresp = b_payload.resp;
    assign b_ready = axi4l_if.bready;

    assign ar_valid = axi4l_if.arvalid;
    assign ar_payload.addr = axi4l_if.araddr;
    assign ar_payload.prot = axi4l_if.arprot;
    assign axi4l_if.arready = ar_ready;
 
    assign axi4l_if.rvalid = r_valid;
    assign axi4l_if.rdata = r_payload.data;
    assign axi4l_if.rresp = r_payload.resp;
    assign r_ready = axi4l_if.rready;

    // Drive write address bus interface
    assign aw_bus_if.srst = srst;
    assign aw_bus_if.valid = aw_valid;
    assign aw_bus_if.data = aw_payload;
    assign aw_ready = aw_bus_if.ready;

    // Drive write data bus interfacce
    assign w_bus_if.srst = srst;
    assign w_bus_if.valid = w_valid;
    assign w_bus_if.data = w_payload;
    assign w_ready = w_bus_if.ready;

    // Drive write response bus interface
    assign b_valid = b_bus_if.valid;
    assign b_payload = b_bus_if.data;
    assign b_bus_if.ready = b_ready;

    // Drive read address bus interface
    assign ar_bus_if.srst = srst;
    assign ar_bus_if.valid = ar_valid;
    assign ar_bus_if.data = ar_payload;
    assign ar_ready = ar_bus_if.ready;

    // Read data
    assign r_valid = r_bus_if.valid;
    assign r_payload = r_bus_if.data;
    assign r_bus_if.ready = r_ready;

endmodule : axi4l_to_bus_adapter
