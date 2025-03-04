interface axi3_intf
    import axi3_pkg::*;
#(
    parameter int  DATA_BYTE_WID = 8,
    parameter int  ADDR_WID = 32,
    parameter type ID_T = logic,
    parameter type USER_T = logic
) (
    // Clock/reset
    input logic aclk
);

    // Signals
    // -- Active-low synchronous reset
    logic                          aresetn;
    // -- Write address
    ID_T                           awid;
    logic [ADDR_WID-1:0]           awaddr;
    logic [3:0]                    awlen;
    axsize_t                       awsize;
    axburst_t                      awburst;
    axlock_t                       awlock;
    axcache_t                      awcache;
    axprot_t                       awprot;
    logic [3:0]                    awqos;
    logic [3:0]                    awregion;
    USER_T                         awuser;
    logic                          awvalid;
    logic                          awready;
    // -- Write data
    ID_T                           wid;
    logic [DATA_BYTE_WID-1:0][7:0] wdata;
    logic [DATA_BYTE_WID-1:0]      wstrb;
    logic                          wlast;
    USER_T                         wuser;
    logic                          wvalid;
    logic                          wready;
    // -- Write response
    ID_T                           bid;
    resp_t                         bresp;
    USER_T                         buser;
    logic                          bvalid;
    logic                          bready;
    // -- Read address
    ID_T                           arid;
    logic [ADDR_WID-1:0]           araddr;
    logic [3:0]                    arlen;
    axsize_t                       arsize;
    axburst_t                      arburst;
    axlock_t                       arlock;
    axcache_t                      arcache;
    axprot_t                       arprot;
    logic [3:0]                    arqos;
    logic [3:0]                    arregion;
    USER_T                         aruser;
    logic                          arvalid;
    logic                          arready;
    // -- Read data
    ID_T                           rid;
    logic [DATA_BYTE_WID-1:0][7:0] rdata;
    resp_t                         rresp;
    logic                          rlast;
    USER_T                         ruser;
    logic                          rvalid;
    logic                          rready;

    // Modports
    modport controller (
        // Clock
        input  aclk,
        // Reset
        output aresetn,
        // Write address
        output awid,
        output awaddr,
        output awlen,
        output awsize,
        output awburst,
        output awlock,
        output awcache,
        output awprot,
        output awqos,
        output awregion,
        output awuser,
        output awvalid,
        input  awready,
        // Write data
        output wid,
        output wdata,
        output wstrb,
        output wlast,
        output wuser,
        output wvalid,
        input  wready,
        // Write response
        input  bid,
        input  bresp,
        input  buser,
        input  bvalid,
        output bready,
        // Read address
        output arid,
        output araddr,
        output arlen,
        output arsize,
        output arburst,
        output arlock,
        output arcache,
        output arprot,
        output arqos,
        output arregion,
        output aruser,
        output arvalid,
        input  arready,
        // Read data
        input  rid,
        input  rdata,
        input  rresp,
        input  rlast,
        input  ruser,
        input  rvalid,
        output rready
    );
       
    modport peripheral (
        // Clock
        input  aclk,
        // Reset
        input  aresetn,
        // Write address
        input  awid,
        input  awaddr,
        input  awlen,
        input  awsize,
        input  awburst,
        input  awlock,
        input  awcache,
        input  awprot,
        input  awqos,
        input  awregion,
        input  awuser,
        input  awvalid,
        output awready,
        // Write data
        input  wid,
        input  wdata,
        input  wstrb,
        input  wlast,
        input  wuser,
        input  wvalid,
        output wready,
        // Write response
        output bid,
        output bresp,
        output buser,
        output bvalid,
        input  bready,
        // Read address
        input  arid,
        input  araddr,
        input  arlen,
        input  arsize,
        input  arburst,
        input  arlock,
        input  arcache,
        input  arprot,
        input  arqos,
        input  arregion,
        input  aruser,
        input  arvalid,
        output arready,
        // Read data
        output rid,
        output rdata,
        output rresp,
        output rlast,
        output ruser,
        output rvalid,
        input  rready
    );

endinterface : axi3_intf

// AXI-3 (back-to-back) connector helper module
module axi3_intf_connector (
    axi3_intf.peripheral axi3_if_from_controller,
    axi3_intf.controller axi3_if_to_peripheral
);
    // Reset
    assign axi3_if_to_peripheral.aresetn = axi3_if_from_controller.aresetn;
    // Write address
    assign axi3_if_to_peripheral.awid = axi3_if_from_controller.awid;
    assign axi3_if_to_peripheral.awaddr = axi3_if_from_controller.awaddr;
    assign axi3_if_to_peripheral.awlen = axi3_if_from_controller.awlen;
    assign axi3_if_to_peripheral.awsize = axi3_if_from_controller.awsize;
    assign axi3_if_to_peripheral.awburst = axi3_if_from_controller.awburst;
    assign axi3_if_to_peripheral.awlock = axi3_if_from_controller.awlock;
    assign axi3_if_to_peripheral.awcache = axi3_if_from_controller.awcache;
    assign axi3_if_to_peripheral.awprot = axi3_if_from_controller.awprot;
    assign axi3_if_to_peripheral.awqos = axi3_if_from_controller.awqos;
    assign axi3_if_to_peripheral.awregion = axi3_if_from_controller.awregion;
    assign axi3_if_to_peripheral.awuser = axi3_if_from_controller.awuser;
    assign axi3_if_to_peripheral.awvalid = axi3_if_from_controller.awvalid;
    assign axi3_if_from_controller.awready = axi3_if_to_peripheral.awready;
    // Write data
    assign axi3_if_to_peripheral.wid = axi3_if_from_controller.wid;
    assign axi3_if_to_peripheral.wdata = axi3_if_from_controller.wdata;
    assign axi3_if_to_peripheral.wstrb = axi3_if_from_controller.wstrb;
    assign axi3_if_to_peripheral.wlast = axi3_if_from_controller.wlast;
    assign axi3_if_to_peripheral.wuser = axi3_if_from_controller.wuser;
    assign axi3_if_to_peripheral.wvalid = axi3_if_from_controller.wvalid;
    assign axi3_if_from_controller.wready = axi3_if_to_peripheral.wready;
    // Write response
    assign axi3_if_from_controller.bid = axi3_if_to_peripheral.bid;
    assign axi3_if_from_controller.bresp = axi3_if_to_peripheral.bresp;
    assign axi3_if_from_controller.buser = axi3_if_to_peripheral.buser;
    assign axi3_if_from_controller.bvalid = axi3_if_to_peripheral.bvalid;
    assign axi3_if_to_peripheral.bready = axi3_if_from_controller.bready;
    // Read address
    assign axi3_if_to_peripheral.arid = axi3_if_from_controller.arid;
    assign axi3_if_to_peripheral.araddr = axi3_if_from_controller.araddr;
    assign axi3_if_to_peripheral.arlen = axi3_if_from_controller.arlen;
    assign axi3_if_to_peripheral.arsize = axi3_if_from_controller.arsize;
    assign axi3_if_to_peripheral.arburst = axi3_if_from_controller.arburst;
    assign axi3_if_to_peripheral.arlock = axi3_if_from_controller.arlock;
    assign axi3_if_to_peripheral.arcache = axi3_if_from_controller.arcache;
    assign axi3_if_to_peripheral.arprot = axi3_if_from_controller.arprot;
    assign axi3_if_to_peripheral.arqos = axi3_if_from_controller.arqos;
    assign axi3_if_to_peripheral.arregion = axi3_if_from_controller.arregion;
    assign axi3_if_to_peripheral.aruser = axi3_if_from_controller.aruser;
    assign axi3_if_to_peripheral.arvalid = axi3_if_from_controller.arvalid;
    assign axi3_if_from_controller.arready = axi3_if_to_peripheral.arready;
    // Read data
    assign axi3_if_from_controller.rid = axi3_if_to_peripheral.rid;
    assign axi3_if_from_controller.rdata = axi3_if_to_peripheral.rdata;
    assign axi3_if_from_controller.rresp = axi3_if_to_peripheral.rresp;
    assign axi3_if_from_controller.ruser = axi3_if_to_peripheral.ruser;
    assign axi3_if_from_controller.rlast = axi3_if_to_peripheral.rlast;
    assign axi3_if_from_controller.rvalid = axi3_if_to_peripheral.rvalid;
    assign axi3_if_to_peripheral.rready = axi3_if_from_controller.rready;

endmodule : axi3_intf_connector


// AXI3 peripheral termination helper module
module axi3_intf_peripheral_term
    import axi3_pkg::*;
(
    axi3_intf.peripheral axi3_if
);
    // Tie off peripheral outputs
    assign axi3_if.awready = 1'b0;
    assign axi3_if.wready = 1'b0;
    assign axi3_if.bid = '0;
    assign axi3_if.bresp = RESP_SLVERR;
    assign axi3_if.buser = '0;
    assign axi3_if.bvalid = 1'b0;
    assign axi3_if.arready = 1'b0;
    assign axi3_if.rid = '0;
    assign axi3_if.rdata = '0;
    assign axi3_if.rresp = RESP_SLVERR;
    assign axi3_if.ruser = '0;
    assign axi3_if.rlast = 1'b0;
    assign axi3_if.rvalid = 1'b0;
endmodule : axi3_intf_peripheral_term


// AXI3 controller termination helper module
module axi3_intf_controller_term (
    axi3_intf.controller axi3_if
);
    import axi3_pkg::*;

    // Tie off controller outputs
    // Reset
    assign axi3_if.aresetn = 1'b0;
    // Write address
    assign axi3_if.awid = '0;
    assign axi3_if.awaddr = '0;
    assign axi3_if.awlen = 4'h0;
    assign axi3_if.awsize = SIZE_1BYTE;
    assign axi3_if.awburst = BURST_INCR;
    assign axi3_if.awlock = LOCK_NORMAL;
    assign axi3_if.awcache = 4'h0;
    assign axi3_if.awprot = 3'h0;
    assign axi3_if.awqos = 4'h0;
    assign axi3_if.awregion = 4'h0;
    assign axi3_if.awuser = '0;
    assign axi3_if.awvalid = 1'b0;
    // Write data
    assign axi3_if.wid = '0;
    assign axi3_if.wdata = '0;
    assign axi3_if.wstrb = '1;
    assign axi3_if.wlast = 1'b0;
    assign axi3_if.wuser = 1'b0;
    assign axi3_if.wvalid = 1'b0;
    // Write response
    assign axi3_if.bready = 1'b0;
    // Read address
    assign axi3_if.arid = '0;
    assign axi3_if.araddr = '0;
    assign axi3_if.arlen = 4'h0;
    assign axi3_if.arsize = SIZE_1BYTE;
    assign axi3_if.arburst = BURST_INCR;
    assign axi3_if.arlock = LOCK_NORMAL;
    assign axi3_if.arcache = 4'h0;
    assign axi3_if.arprot = 3'h0;
    assign axi3_if.arqos = 4'h0;
    assign axi3_if.arregion = 4'h0;
    assign axi3_if.aruser = '0;
    assign axi3_if.arvalid = 1'b0;
    // Read data
    assign axi3_if.rready = 1'b0;
endmodule : axi3_intf_controller_term


// Collect flattened AXI3 signals (from controller) into interface (to peripheral)
module axi3_intf_from_signals
    import axi3_pkg::*;
#(
    parameter int DATA_BYTE_WID = 8,
    parameter int ADDR_WID = 32,
    parameter type ID_T = logic,
    parameter type USER_T = logic
) (
    // Signals (from controller)
    // -- Reset
    input  logic                          aresetn,
    // -- Write address
    input  ID_T                           awid,
    input  logic [ADDR_WID-1:0]           awaddr,
    input  logic [3:0]                    awlen,
    input  logic [2:0]                    awsize,
    input  logic [1:0]                    awburst,
    input  logic [1:0]                    awlock,
    input  logic [3:0]                    awcache,
    input  logic [2:0]                    awprot,
    input  logic [3:0]                    awqos,
    input  logic [3:0]                    awregion,
    input  USER_T                         awuser,
    input  logic                          awvalid,
    output logic                          awready,
    // -- Write data
    input  ID_T                           wid,
    input  logic [DATA_BYTE_WID-1:0][7:0] wdata,
    input  logic [DATA_BYTE_WID-1:0]      wstrb,
    input  logic                          wlast,
    input  USER_T                         wuser,
    input  logic                          wvalid,
    output logic                          wready,
    // -- Write response
    output ID_T                           bid,
    output logic [1:0]                    bresp,
    output USER_T                         buser,
    output logic                          bvalid,
    input  logic                          bready,
    // -- Read address
    input  ID_T                           arid,
    input  logic [ADDR_WID-1:0]           araddr,
    input  logic [3:0]                    arlen,
    input  logic [2:0]                    arsize,
    input  logic [1:0]                    arburst,
    input  logic [1:0]                    arlock,
    input  logic [3:0]                    arcache,
    input  logic [2:0]                    arprot,
    input  logic [3:0]                    arqos,
    input  logic [3:0]                    arregion,
    input  USER_T                         aruser,
    input  logic                          arvalid,
    output logic                          arready,
    // -- Read data
    output ID_T                           rid,
    output logic [DATA_BYTE_WID-1:0][7:0] rdata,
    output logic [1:0]                    rresp,
    output logic                          rlast,
    output USER_T                         ruser,
    output logic                          rvalid,
    input  logic                          rready,

    // Interface (to peripheral)
    axi3_intf.controller                  axi3_if
);
    // Reset
    assign axi3_if.aresetn = aresetn;
    // Write address
    assign axi3_if.awid = awid;
    assign axi3_if.awaddr = awaddr;
    assign axi3_if.awlen = awlen;
    assign axi3_if.awsize = awsize;
    assign axi3_if.awburst = awburst;
    assign axi3_if.awlock = awlock;
    assign axi3_if.awcache = awcache;
    assign axi3_if.awprot = awprot;
    assign axi3_if.awqos = awqos;
    assign axi3_if.awregion = awregion;
    assign axi3_if.awuser = awuser;
    assign axi3_if.awvalid = awvalid;
    assign awready = axi3_if.awready;
    // Write data
    assign axi3_if.wid = wid;
    assign axi3_if.wdata = wdata;
    assign axi3_if.wstrb = wstrb;
    assign axi3_if.wlast = wlast;
    assign axi3_if.wuser = wuser;
    assign axi3_if.wvalid = wvalid;
    assign wready = axi3_if.wready;
    // Write response
    assign bid = axi3_if.bid;
    assign bresp = axi3_if.bresp;
    assign buser = axi3_if.buser;
    assign bvalid = axi3_if.bvalid;
    assign axi3_if.bready = bready;
    // Read address
    assign axi3_if.arid = arid;
    assign axi3_if.araddr = araddr;
    assign axi3_if.arlen = arlen;
    assign axi3_if.arsize = arsize;
    assign axi3_if.arburst = arburst;
    assign axi3_if.arlock = arlock;
    assign axi3_if.arcache = arcache;
    assign axi3_if.arprot = arprot;
    assign axi3_if.arqos = arqos;
    assign axi3_if.arregion = arregion;
    assign axi3_if.aruser = aruser;
    assign axi3_if.arvalid = arvalid;
    assign arready = axi3_if.arready;
    // Read data
    assign rid = axi3_if.rid;
    assign rdata = axi3_if.rdata;
    assign rresp = axi3_if.rresp;
    assign ruser = axi3_if.ruser;
    assign rlast = axi3_if.rlast;
    assign rvalid = axi3_if.rvalid;
    assign axi3_if.rready = rready;

endmodule : axi3_intf_from_signals


// Break interface (from controller) into flattened AXI3 signals (to controller)
module axi3_intf_to_signals
    import axi3_pkg::*;
#(
    parameter int DATA_BYTE_WID = 8,
    parameter int ADDR_WID = 32,
    parameter type ID_T = logic,
    parameter type USER_T = logic
) (
    // Interface (from controller)
    axi3_intf.peripheral                  axi3_if,
 
    // Signals (to peripheral)
    // -- Reset
    output logic                          aresetn,
    // -- Write address
    output ID_T                           awid,
    output logic [ADDR_WID-1:0]           awaddr,
    output logic [3:0]                    awlen,
    output logic [2:0]                    awsize,
    output logic [1:0]                    awburst,
    output logic [1:0]                    awlock,
    output logic [3:0]                    awcache,
    output logic [2:0]                    awprot,
    output logic [3:0]                    awqos,
    output logic [3:0]                    awregion,
    output USER_T                         awuser,
    output logic                          awvalid,
    input  logic                          awready,
    // -- Write data
    output ID_T                           wid,
    output logic [DATA_BYTE_WID-1:0][7:0] wdata,
    output logic [DATA_BYTE_WID-1:0]      wstrb,
    output logic                          wlast,
    output USER_T                         wuser,
    output logic                          wvalid,
    input  logic                          wready,
    // -- Write response
    input  ID_T                           bid,
    input  logic [1:0]                    bresp,
    input  USER_T                         buser,
    input  logic                          bvalid,
    output logic                          bready,
    // -- Read address
    output ID_T                           arid,
    output logic [ADDR_WID-1:0]           araddr,
    output logic [3:0]                    arlen,
    output logic [2:0]                    arsize,
    output logic [1:0]                    arburst,
    output logic [1:0]                    arlock,
    output logic [3:0]                    arcache,
    output logic [2:0]                    arprot,
    output logic [3:0]                    arqos,
    output logic [3:0]                    arregion,
    output USER_T                         aruser,
    output logic                          arvalid,
    input  logic                          arready,
    // -- Read data
    input  ID_T                           rid,
    input  logic [DATA_BYTE_WID-1:0][7:0] rdata,
    input  logic [1:0]                    rresp,
    input  logic                          rlast,
    input  USER_T                         ruser,
    input  logic                          rvalid,
    output logic                          rready
);
    // Reset
    assign aresetn = axi3_if.aresetn;
    // Write address
    assign awid = axi3_if.awid;
    assign awaddr = axi3_if.awaddr;
    assign awlen = axi3_if.awlen;
    assign awsize = axi3_if.awsize;
    assign awburst = axi3_if.awburst;
    assign awlock = axi3_if.awlock;
    assign awcache = axi3_if.awcache;
    assign awprot = axi3_if.awprot;
    assign awqos = axi3_if.awqos;
    assign awregion = axi3_if.awregion;
    assign awuser = axi3_if.awuser;
    assign awvalid = axi3_if.awvalid;
    assign axi3_if.awready = awready;
    // Write data
    assign wid = axi3_if.wid;
    assign wdata = axi3_if.wdata;
    assign wstrb = axi3_if.wstrb;
    assign wlast = axi3_if.wlast;
    assign wuser = axi3_if.wuser;
    assign wvalid = axi3_if.wvalid;
    assign axi3_if.wready = wready;
    // Write response
    assign axi3_if.bid = bid;
    assign axi3_if.bresp = bresp;
    assign axi3_if.buser = buser;
    assign axi3_if.bvalid = bvalid;
    assign bready = axi3_if.bready;
    // Read address
    assign arid = axi3_if.arid;
    assign araddr = axi3_if.araddr;
    assign arlen = axi3_if.arlen;
    assign arsize = axi3_if.arsize;
    assign arburst = axi3_if.arburst;
    assign arlock = axi3_if.arlock;
    assign arcache = axi3_if.arcache;
    assign arprot = axi3_if.arprot;
    assign arqos = axi3_if.arqos;
    assign arregion = axi3_if.arregion;
    assign aruser = axi3_if.aruser;
    assign arvalid = axi3_if.arvalid;
    assign axi3_if.arready = arready;
    // Read data
    assign axi3_if.rid = rid;
    assign axi3_if.rdata = rdata;
    assign axi3_if.rresp = rresp;
    assign axi3_if.ruser = ruser;
    assign axi3_if.rlast = rlast;
    assign axi3_if.rvalid = rvalid;
    assign rready = axi3_if.rready;

endmodule : axi3_intf_to_signals
