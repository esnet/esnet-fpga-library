interface axi3_intf
    import axi3_pkg::*;
#(
    parameter int DATA_BYTE_WID = 8,
    parameter int ADDR_WID = 32,
    parameter int ID_WID = 1,
    parameter int USER_WID = 1
) (
    // Clock/reset
    input logic aclk,
    input logic aresetn = 1'b1
);

    // Parameter validation
    initial begin
        std_pkg::param_check_gt(DATA_BYTE_WID, 1, "DATA_BYTE_WID");
        std_pkg::param_check_gt(ADDR_WID,      1, "ADDR_WID");
        std_pkg::param_check_gt(ID_WID,        1, "ID_WID");
        std_pkg::param_check_gt(USER_WID,      1, "USER_WID");
    end

    // Signals
    // -- Write address
    logic [ID_WID-1:0]             awid;
    logic [ADDR_WID-1:0]           awaddr;
    logic [3:0]                    awlen;
    axsize_t                       awsize;
    axburst_t                      awburst;
    axlock_t                       awlock;
    axcache_t                      awcache;
    axprot_t                       awprot;
    logic [3:0]                    awqos;
    logic [3:0]                    awregion;
    logic [USER_WID-1:0]           awuser;
    logic                          awvalid;
    logic                          awready;
    // -- Write data
    logic [ID_WID-1:0]             wid;
    logic [DATA_BYTE_WID-1:0][7:0] wdata;
    logic [DATA_BYTE_WID-1:0]      wstrb;
    logic                          wlast;
    logic [USER_WID-1:0]           wuser;
    logic                          wvalid;
    logic                          wready;
    // -- Write response
    logic [ID_WID-1:0]             bid;
    resp_t                         bresp;
    logic [USER_WID-1:0]           buser;
    logic                          bvalid;
    logic                          bready;
    // -- Read address
    logic [ID_WID-1:0]             arid;
    logic [ADDR_WID-1:0]           araddr;
    logic [3:0]                    arlen;
    axsize_t                       arsize;
    axburst_t                      arburst;
    axlock_t                       arlock;
    axcache_t                      arcache;
    axprot_t                       arprot;
    logic [3:0]                    arqos;
    logic [3:0]                    arregion;
    logic [USER_WID-1:0]           aruser;
    logic                          arvalid;
    logic                          arready;
    // -- Read data
    logic [ID_WID-1:0]             rid;
    logic [DATA_BYTE_WID-1:0][7:0] rdata;
    resp_t                         rresp;
    logic                          rlast;
    logic [USER_WID-1:0]           ruser;
    logic                          rvalid;
    logic                          rready;

    // Modports
    modport controller (
        // Clock
        input  aclk,
        // Reset
        input  aresetn,
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

// AXI-3 interface parameter check component
module axi3_intf_parameter_check (
    axi3_intf.peripheral from_controller,
    axi3_intf.controller to_peripheral
);
    initial begin
        std_pkg::param_check(from_controller.DATA_BYTE_WID, to_peripheral.DATA_BYTE_WID, "DATA_BYTE_WID");
        std_pkg::param_check(from_controller.ADDR_WID,      to_peripheral.ADDR_WID,      "ADDR_WID");
        std_pkg::param_check(from_controller.ID_WID,        to_peripheral.ID_WID,        "ID_WID");
        std_pkg::param_check(from_controller.USER_WID,      to_peripheral.USER_WID,      "USER_WID");
    end

endmodule

// AXI-3 (back-to-back) connector helper module
module axi3_intf_connector (
    axi3_intf.peripheral from_controller,
    axi3_intf.controller to_peripheral
);
    axi3_intf_parameter_check param_check (.*);

    // Write address
    assign to_peripheral.awid = from_controller.awid;
    assign to_peripheral.awaddr = from_controller.awaddr;
    assign to_peripheral.awlen = from_controller.awlen;
    assign to_peripheral.awsize = from_controller.awsize;
    assign to_peripheral.awburst = from_controller.awburst;
    assign to_peripheral.awlock = from_controller.awlock;
    assign to_peripheral.awcache = from_controller.awcache;
    assign to_peripheral.awprot = from_controller.awprot;
    assign to_peripheral.awqos = from_controller.awqos;
    assign to_peripheral.awregion = from_controller.awregion;
    assign to_peripheral.awuser = from_controller.awuser;
    assign to_peripheral.awvalid = from_controller.awvalid;
    assign from_controller.awready = to_peripheral.awready;
    // Write data
    assign to_peripheral.wid = from_controller.wid;
    assign to_peripheral.wdata = from_controller.wdata;
    assign to_peripheral.wstrb = from_controller.wstrb;
    assign to_peripheral.wlast = from_controller.wlast;
    assign to_peripheral.wuser = from_controller.wuser;
    assign to_peripheral.wvalid = from_controller.wvalid;
    assign from_controller.wready = to_peripheral.wready;
    // Write response
    assign from_controller.bid = to_peripheral.bid;
    assign from_controller.bresp = to_peripheral.bresp;
    assign from_controller.buser = to_peripheral.buser;
    assign from_controller.bvalid = to_peripheral.bvalid;
    assign to_peripheral.bready = from_controller.bready;
    // Read address
    assign to_peripheral.arid = from_controller.arid;
    assign to_peripheral.araddr = from_controller.araddr;
    assign to_peripheral.arlen = from_controller.arlen;
    assign to_peripheral.arsize = from_controller.arsize;
    assign to_peripheral.arburst = from_controller.arburst;
    assign to_peripheral.arlock = from_controller.arlock;
    assign to_peripheral.arcache = from_controller.arcache;
    assign to_peripheral.arprot = from_controller.arprot;
    assign to_peripheral.arqos = from_controller.arqos;
    assign to_peripheral.arregion = from_controller.arregion;
    assign to_peripheral.aruser = from_controller.aruser;
    assign to_peripheral.arvalid = from_controller.arvalid;
    assign from_controller.arready = to_peripheral.arready;
    // Read data
    assign from_controller.rid = to_peripheral.rid;
    assign from_controller.rdata = to_peripheral.rdata;
    assign from_controller.rresp = to_peripheral.rresp;
    assign from_controller.ruser = to_peripheral.ruser;
    assign from_controller.rlast = to_peripheral.rlast;
    assign from_controller.rvalid = to_peripheral.rvalid;
    assign to_peripheral.rready = from_controller.rready;

endmodule : axi3_intf_connector


// AXI3 peripheral termination helper module
module axi3_intf_peripheral_term (
    axi3_intf.peripheral from_controller
);
    import axi3_pkg::*;

    // Tie off peripheral outputs
    assign from_controller.awready = 1'b0;
    assign from_controller.wready = 1'b0;
    assign from_controller.bid = '0;
    assign from_controller.bresp = RESP_SLVERR;
    assign from_controller.buser = '0;
    assign from_controller.bvalid = 1'b0;
    assign from_controller.arready = 1'b0;
    assign from_controller.rid = '0;
    assign from_controller.rdata = '0;
    assign from_controller.rresp = RESP_SLVERR;
    assign from_controller.ruser = '0;
    assign from_controller.rlast = 1'b0;
    assign from_controller.rvalid = 1'b0;
endmodule : axi3_intf_peripheral_term


// AXI3 controller termination helper module
module axi3_intf_controller_term (
    axi3_intf.controller to_peripheral
);
    import axi3_pkg::*;

    // Tie off controller outputs
    // Write address
    assign to_peripheral.awid = '0;
    assign to_peripheral.awaddr = '0;
    assign to_peripheral.awlen = 4'h0;
    assign to_peripheral.awsize = SIZE_1BYTE;
    assign to_peripheral.awburst = BURST_INCR;
    assign to_peripheral.awlock = LOCK_NORMAL;
    assign to_peripheral.awcache = 4'h0;
    assign to_peripheral.awprot = 3'h0;
    assign to_peripheral.awqos = 4'h0;
    assign to_peripheral.awregion = 4'h0;
    assign to_peripheral.awuser = '0;
    assign to_peripheral.awvalid = 1'b0;
    // Write data
    assign to_peripheral.wid = '0;
    assign to_peripheral.wdata = '0;
    assign to_peripheral.wstrb = '1;
    assign to_peripheral.wlast = 1'b0;
    assign to_peripheral.wuser = 1'b0;
    assign to_peripheral.wvalid = 1'b0;
    // Write response
    assign to_peripheral.bready = 1'b0;
    // Read address
    assign to_peripheral.arid = '0;
    assign to_peripheral.araddr = '0;
    assign to_peripheral.arlen = 4'h0;
    assign to_peripheral.arsize = SIZE_1BYTE;
    assign to_peripheral.arburst = BURST_INCR;
    assign to_peripheral.arlock = LOCK_NORMAL;
    assign to_peripheral.arcache = 4'h0;
    assign to_peripheral.arprot = 3'h0;
    assign to_peripheral.arqos = 4'h0;
    assign to_peripheral.arregion = 4'h0;
    assign to_peripheral.aruser = '0;
    assign to_peripheral.arvalid = 1'b0;
    // Read data
    assign to_peripheral.rready = 1'b0;
endmodule : axi3_intf_controller_term


// Collect flattened AXI3 signals (from controller) into interface (to peripheral)
module axi3_intf_from_signals
    import axi3_pkg::*;
#(
    parameter int DATA_BYTE_WID = 8,
    parameter int ADDR_WID = 32,
    parameter int ID_WID = 1,
    parameter int USER_WID = 1
) (
    // Signals (from controller)
    // -- Write address
    input  logic [ID_WID-1:0]             awid,
    input  logic [ADDR_WID-1:0]           awaddr,
    input  logic [3:0]                    awlen,
    input  logic [2:0]                    awsize,
    input  logic [1:0]                    awburst,
    input  logic [1:0]                    awlock,
    input  logic [3:0]                    awcache,
    input  logic [2:0]                    awprot,
    input  logic [3:0]                    awqos,
    input  logic [3:0]                    awregion,
    input  logic [USER_WID-1:0]           awuser,
    input  logic                          awvalid,
    output logic                          awready,
    // -- Write data
    input  logic [ID_WID-1:0]             wid,
    input  logic [DATA_BYTE_WID-1:0][7:0] wdata,
    input  logic [DATA_BYTE_WID-1:0]      wstrb,
    input  logic                          wlast,
    input  logic [USER_WID-1:0]           wuser,
    input  logic                          wvalid,
    output logic                          wready,
    // -- Write response
    output logic [ID_WID-1:0]             bid,
    output logic [1:0]                    bresp,
    output logic [USER_WID-1:0]           buser,
    output logic                          bvalid,
    input  logic                          bready,
    // -- Read address
    input  logic [ID_WID-1:0]             arid,
    input  logic [ADDR_WID-1:0]           araddr,
    input  logic [3:0]                    arlen,
    input  logic [2:0]                    arsize,
    input  logic [1:0]                    arburst,
    input  logic [1:0]                    arlock,
    input  logic [3:0]                    arcache,
    input  logic [2:0]                    arprot,
    input  logic [3:0]                    arqos,
    input  logic [3:0]                    arregion,
    input  logic [USER_WID-1:0]           aruser,
    input  logic                          arvalid,
    output logic                          arready,
    // -- Read data
    output logic [ID_WID-1:0]             rid,
    output logic [DATA_BYTE_WID-1:0][7:0] rdata,
    output logic [1:0]                    rresp,
    output logic                          rlast,
    output logic [USER_WID-1:0]           ruser,
    output logic                          rvalid,
    input  logic                          rready,

    // Interface (to peripheral)
    axi3_intf.controller                  axi3_if
);
    // Parameter check
    initial begin
        std_pkg::param_check(axi3_if.DATA_BYTE_WID, DATA_BYTE_WID, "axi3_if.DATA_BYTE_WID");
        std_pkg::param_check(axi3_if.ADDR_WID,      ADDR_WID,      "axi3_if.ADDR_WID");
        std_pkg::param_check(axi3_if.ID_WID,        ID_WID,        "axi3_if.ID_WID");
        std_pkg::param_check(axi3_if.USER_WID,      USER_WID,      "axi3_if.USER_WID");
    end

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
    parameter int ID_WID = 1,
    parameter int USER_WID = 1
) (
     // Interface (from controller)
    axi3_intf.peripheral                  axi3_if,
 
    // Signals (to peripheral)
    // -- Clock/reset
    output logic                          aclk,
    output logic                          aresetn,
    // -- Write address
    output logic [ID_WID-1:0]             awid,
    output logic [ADDR_WID-1:0]           awaddr,
    output logic [3:0]                    awlen,
    output logic [2:0]                    awsize,
    output logic [1:0]                    awburst,
    output logic [1:0]                    awlock,
    output logic [3:0]                    awcache,
    output logic [2:0]                    awprot,
    output logic [3:0]                    awqos,
    output logic [3:0]                    awregion,
    output logic [USER_WID-1:0]           awuser,
    output logic                          awvalid,
    input  logic                          awready,
    // -- Write data
    output logic [ID_WID-1:0]             wid,
    output logic [DATA_BYTE_WID-1:0][7:0] wdata,
    output logic [DATA_BYTE_WID-1:0]      wstrb,
    output logic                          wlast,
    output logic [USER_WID-1:0]           wuser,
    output logic                          wvalid,
    input  logic                          wready,
    // -- Write response
    input  logic [ID_WID-1:0]             bid,
    input  logic [1:0]                    bresp,
    input  logic [USER_WID-1:0]           buser,
    input  logic                          bvalid,
    output logic                          bready,
    // -- Read address
    output logic [ID_WID-1:0]             arid,
    output logic [ADDR_WID-1:0]           araddr,
    output logic [3:0]                    arlen,
    output logic [2:0]                    arsize,
    output logic [1:0]                    arburst,
    output logic [1:0]                    arlock,
    output logic [3:0]                    arcache,
    output logic [2:0]                    arprot,
    output logic [3:0]                    arqos,
    output logic [3:0]                    arregion,
    output logic [USER_WID-1:0]           aruser,
    output logic                          arvalid,
    input  logic                          arready,
    // -- Read data
    input  logic [ID_WID-1:0]             rid,
    input  logic [DATA_BYTE_WID-1:0][7:0] rdata,
    input  logic [1:0]                    rresp,
    input  logic                          rlast,
    input  logic [USER_WID-1:0]           ruser,
    input  logic                          rvalid,
    output logic                          rready
);
    // Parameter check
    initial begin
        std_pkg::param_check(axi3_if.DATA_BYTE_WID, DATA_BYTE_WID, "axi3_if.DATA_BYTE_WID");
        std_pkg::param_check(axi3_if.ADDR_WID,      ADDR_WID,      "axi3_if.ADDR_WID");
        std_pkg::param_check(axi3_if.ID_WID,        ID_WID,        "axi3_if.ID_WID");
        std_pkg::param_check(axi3_if.USER_WID,      USER_WID,      "axi3_if.USER_WID");
    end

    // Clock/reset
    assign aclk = axi3_if.aclk;
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
