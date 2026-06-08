// =============================================================================
// AXI4 interface, helper modules, and signal adaptors.
//
// Key AXI4 differences from AXI3:
//   - AxLEN is 8 bits (vs 4)
//   - AxLOCK is 1 bit (vs 2)
//   - No WID on the write data channel
//   - AxQOS and AxREGION are part of the spec (vs optional in AXI3)
// =============================================================================

interface axi4_intf
    import axi4_pkg::*;
#(
    parameter int DATA_BYTE_WID = 8,
    parameter int ADDR_WID      = 32,
    parameter int ID_WID        = 1,
    parameter int USER_WID      = 1
) (
    input logic aclk
);
    // Parameter validation
    initial begin
        std_pkg::param_check_gt(DATA_BYTE_WID, 1, "DATA_BYTE_WID");
        std_pkg::param_check_gt(ADDR_WID,      1, "ADDR_WID");
        std_pkg::param_check_gt(ID_WID,        1, "ID_WID");
        std_pkg::param_check_gt(USER_WID,      1, "USER_WID");
    end

    // Derived
    localparam int DATA_WID = DATA_BYTE_WID * 8;

    // Write address
    logic [ID_WID-1:0]             awid;
    logic [ADDR_WID-1:0]           awaddr;
    logic [7:0]                    awlen;
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
    // Write data (no WID in AXI4)
    logic [DATA_BYTE_WID-1:0][7:0] wdata;
    logic [DATA_BYTE_WID-1:0]      wstrb;
    logic                          wlast;
    logic [USER_WID-1:0]           wuser;
    logic                          wvalid;
    logic                          wready;
    // Write response
    logic [ID_WID-1:0]             bid;
    resp_t                         bresp;
    logic [USER_WID-1:0]           buser;
    logic                          bvalid;
    logic                          bready;
    // Read address
    logic [ID_WID-1:0]             arid;
    logic [ADDR_WID-1:0]           araddr;
    logic [7:0]                    arlen;
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
    // Read data
    logic [ID_WID-1:0]             rid;
    logic [DATA_BYTE_WID-1:0][7:0] rdata;
    resp_t                         rresp;
    logic                          rlast;
    logic [USER_WID-1:0]           ruser;
    logic                          rvalid;
    logic                          rready;

    // (Local) parameters
    localparam int DEFAULT_WR_TIMEOUT = 256;
    localparam int DEFAULT_RD_TIMEOUT = 256;

    // ------------------------------------------------------------------
    // Clocking block — controller perspective
    // ------------------------------------------------------------------
    clocking cb @(posedge aclk);
        output awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot,
               awqos, awregion, awuser;
        output wdata, wstrb, wlast, wuser;
        output arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot,
               arqos, arregion, aruser;
        inout  awvalid, wvalid, bready, arvalid, rready;
        input  awready, wready, bid, bresp, buser, bvalid;
        input  arready, rid, rdata, rresp, rlast, ruser, rvalid;
    endclocking

    // ------------------------------------------------------------------
    // Tasks
    // ------------------------------------------------------------------

    task idle_controller();
        cb.awvalid  <= 1'b0;
        cb.awid     <= '0;
        cb.awaddr   <= '0;
        cb.awlen    <= 8'h0;
        cb.awsize   <= SIZE_4BYTES;
        cb.awburst  <= BURST_INCR;
        cb.awlock   <= LOCK_NORMAL;
        cb.awcache  <= '0;
        cb.awprot   <= '0;
        cb.awqos    <= '0;
        cb.awregion <= '0;
        cb.awuser   <= '0;
        cb.wvalid   <= 1'b0;
        cb.wdata    <= '0;
        cb.wstrb    <= '0;
        cb.wlast    <= 1'b0;
        cb.wuser    <= '0;
        cb.bready   <= 1'b0;
        cb.arvalid  <= 1'b0;
        cb.arid     <= '0;
        cb.araddr   <= '0;
        cb.arlen    <= 8'h0;
        cb.arsize   <= SIZE_4BYTES;
        cb.arburst  <= BURST_INCR;
        cb.arlock   <= LOCK_NORMAL;
        cb.arcache  <= '0;
        cb.arprot   <= '0;
        cb.arqos    <= '0;
        cb.arregion <= '0;
        cb.aruser   <= '0;
        cb.rready   <= 1'b0;
        @(cb);
    endtask

    task _wait(input int cycles);
        repeat (cycles) @(cb);
    endtask

    // Single-beat read — no timeout guard, call read() from testbenches.
    task _read(
            input  bit [ADDR_WID-1:0]             addr,
            input  bit [ID_WID-1:0]               id,
            input  bit [2:0]                       prot,
            output bit [DATA_BYTE_WID-1:0][7:0]   data,
            output bit [1:0]                       resp
        );
        cb.arvalid  <= 1'b1;
        cb.arid     <= id;
        cb.araddr   <= addr;
        cb.arlen    <= 8'h0;
        cb.arsize   <= SIZE_4BYTES;
        cb.arburst  <= BURST_INCR;
        cb.arlock   <= LOCK_NORMAL;
        cb.arprot   <= prot;
        cb.rready   <= 1'b0;
        @(cb);
        wait(cb.arvalid && cb.arready);
        cb.arvalid <= 1'b0;
        cb.araddr  <= 'x;
        cb.rready  <= 1'b1;
        @(cb);
        wait(cb.rvalid && cb.rready);
        cb.rready <= 1'b0;
        resp = cb.rresp;
        data = cb.rdata;
    endtask

    task read(
            input  bit [ADDR_WID-1:0]             addr,
            output bit [DATA_BYTE_WID-1:0][7:0]   data,
            output bit [1:0]                       resp,
            output bit                             timeout,
            input  int                             RD_TIMEOUT = DEFAULT_RD_TIMEOUT
        );
        automatic bit [DATA_BYTE_WID-1:0][7:0] _data    = '0;
        automatic bit [1:0]                    _resp    = RESP_SLVERR;
        automatic bit                          _timeout = 1'b0;
        fork
            begin
                fork
                    _read(addr, '0, '0, _data, _resp);
                    begin
                        if (RD_TIMEOUT > 0) begin
                            _wait(RD_TIMEOUT);
                            _timeout = 1'b1;
                        end else forever _wait(1);
                    end
                join_any
                disable fork;
            end
        join
        if (_timeout) idle_controller();
        data    = _data;
        resp    = _resp;
        timeout = _timeout;
    endtask

    // Single-beat write — no timeout guard, call write() from testbenches.
    task _write(
            input  bit [ADDR_WID-1:0]             addr,
            input  bit [DATA_BYTE_WID-1:0][7:0]   data,
            input  bit [DATA_BYTE_WID-1:0]         strb,
            input  bit [ID_WID-1:0]               id,
            input  bit [2:0]                       prot,
            output bit [1:0]                       resp
        );
        // AW and W channels are independent — issue concurrently.
        fork
            begin
                cb.awvalid  <= 1'b1;
                cb.awid     <= id;
                cb.awaddr   <= addr;
                cb.awlen    <= 8'h0;
                cb.awsize   <= SIZE_4BYTES;
                cb.awburst  <= BURST_INCR;
                cb.awlock   <= LOCK_NORMAL;
                cb.awprot   <= prot;
                @(cb);
                wait(cb.awvalid && cb.awready);
                cb.awvalid <= 1'b0;
                cb.awaddr  <= 'x;
            end
            begin
                cb.wvalid <= 1'b1;
                cb.wdata  <= data;
                cb.wstrb  <= strb;
                cb.wlast  <= 1'b1;
                @(cb);
                wait(cb.wvalid && cb.wready);
                cb.wvalid <= 1'b0;
                cb.wdata  <= 'x;
                cb.wstrb  <= 'x;
                cb.wlast  <= 1'b0;
            end
        join
        cb.bready <= 1'b1;
        @(cb);
        wait(cb.bvalid && cb.bready);
        cb.bready <= 1'b0;
        resp = cb.bresp;
    endtask

    task write(
            input  bit [ADDR_WID-1:0]             addr,
            input  bit [DATA_BYTE_WID-1:0][7:0]   data,
            input  bit [DATA_BYTE_WID-1:0]         strb,
            output bit [1:0]                       resp,
            output bit                             timeout,
            input  int                             WR_TIMEOUT = DEFAULT_WR_TIMEOUT
        );
        automatic bit [1:0] _resp    = RESP_SLVERR;
        automatic bit       _timeout = 1'b0;
        fork
            begin
                fork
                    _write(addr, data, strb, '0, '0, _resp);
                    begin
                        if (WR_TIMEOUT > 0) begin
                            _wait(WR_TIMEOUT);
                            _timeout = 1'b1;
                        end else forever _wait(1);
                    end
                join_any
                disable fork;
            end
        join
        if (_timeout) idle_controller();
        resp    = _resp;
        timeout = _timeout;
    endtask

    modport controller (
        input  aclk,
        output awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot,
               awqos, awregion, awuser, awvalid,
        input  awready,
        output wdata, wstrb, wlast, wuser, wvalid,
        input  wready,
        input  bid, bresp, buser, bvalid,
        output bready,
        output arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot,
               arqos, arregion, aruser, arvalid,
        input  arready,
        input  rid, rdata, rresp, rlast, ruser, rvalid,
        output rready
    );

    modport peripheral (
        input  aclk,
        input  awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot,
               awqos, awregion, awuser, awvalid,
        output awready,
        input  wdata, wstrb, wlast, wuser, wvalid,
        output wready,
        output bid, bresp, buser, bvalid,
        input  bready,
        input  arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot,
               arqos, arregion, aruser, arvalid,
        output arready,
        output rid, rdata, rresp, rlast, ruser, rvalid,
        input  rready
    );

endinterface : axi4_intf


// Back-to-back connector
module axi4_intf_connector (
    axi4_intf.peripheral from_controller,
    axi4_intf.controller to_peripheral
);
    initial begin
        std_pkg::param_check(from_controller.DATA_BYTE_WID, to_peripheral.DATA_BYTE_WID, "DATA_BYTE_WID");
        std_pkg::param_check(from_controller.ADDR_WID,      to_peripheral.ADDR_WID,      "ADDR_WID");
        std_pkg::param_check(from_controller.ID_WID,        to_peripheral.ID_WID,        "ID_WID");
        std_pkg::param_check(from_controller.USER_WID,      to_peripheral.USER_WID,      "USER_WID");
    end

    assign to_peripheral.awid     = from_controller.awid;
    assign to_peripheral.awaddr   = from_controller.awaddr;
    assign to_peripheral.awlen    = from_controller.awlen;
    assign to_peripheral.awsize   = from_controller.awsize;
    assign to_peripheral.awburst  = from_controller.awburst;
    assign to_peripheral.awlock   = from_controller.awlock;
    assign to_peripheral.awcache  = from_controller.awcache;
    assign to_peripheral.awprot   = from_controller.awprot;
    assign to_peripheral.awqos    = from_controller.awqos;
    assign to_peripheral.awregion = from_controller.awregion;
    assign to_peripheral.awuser   = from_controller.awuser;
    assign to_peripheral.awvalid  = from_controller.awvalid;
    assign from_controller.awready = to_peripheral.awready;

    assign to_peripheral.wdata    = from_controller.wdata;
    assign to_peripheral.wstrb    = from_controller.wstrb;
    assign to_peripheral.wlast    = from_controller.wlast;
    assign to_peripheral.wuser    = from_controller.wuser;
    assign to_peripheral.wvalid   = from_controller.wvalid;
    assign from_controller.wready = to_peripheral.wready;

    assign from_controller.bid    = to_peripheral.bid;
    assign from_controller.bresp  = to_peripheral.bresp;
    assign from_controller.buser  = to_peripheral.buser;
    assign from_controller.bvalid = to_peripheral.bvalid;
    assign to_peripheral.bready   = from_controller.bready;

    assign to_peripheral.arid     = from_controller.arid;
    assign to_peripheral.araddr   = from_controller.araddr;
    assign to_peripheral.arlen    = from_controller.arlen;
    assign to_peripheral.arsize   = from_controller.arsize;
    assign to_peripheral.arburst  = from_controller.arburst;
    assign to_peripheral.arlock   = from_controller.arlock;
    assign to_peripheral.arcache  = from_controller.arcache;
    assign to_peripheral.arprot   = from_controller.arprot;
    assign to_peripheral.arqos    = from_controller.arqos;
    assign to_peripheral.arregion = from_controller.arregion;
    assign to_peripheral.aruser   = from_controller.aruser;
    assign to_peripheral.arvalid  = from_controller.arvalid;
    assign from_controller.arready = to_peripheral.arready;

    assign from_controller.rid    = to_peripheral.rid;
    assign from_controller.rdata  = to_peripheral.rdata;
    assign from_controller.rresp  = to_peripheral.rresp;
    assign from_controller.rlast  = to_peripheral.rlast;
    assign from_controller.ruser  = to_peripheral.ruser;
    assign from_controller.rvalid = to_peripheral.rvalid;
    assign to_peripheral.rready   = from_controller.rready;

endmodule : axi4_intf_connector


// Peripheral termination (returns SLVERR to all transactions)
module axi4_intf_peripheral_term (
    axi4_intf.peripheral from_controller
);
    import axi4_pkg::*;

    // Accept then immediately complete with SLVERR
    // Write path: must track AW→W→B sequence
    logic aw_active, w_done;

    always_ff @(posedge from_controller.aclk) begin
        if (!from_controller.awvalid) begin
            aw_active <= 1'b0;
            w_done    <= 1'b0;
        end else begin
            if (from_controller.awvalid && from_controller.awready) aw_active <= 1'b1;
            if (from_controller.wvalid  && from_controller.wready && from_controller.wlast) w_done <= 1'b1;
        end
    end

    assign from_controller.awready = 1'b1;
    assign from_controller.wready  = 1'b1;
    assign from_controller.bid     = '0;
    assign from_controller.bresp   = RESP_SLVERR;
    assign from_controller.buser   = '0;
    assign from_controller.bvalid  = aw_active & w_done;

    assign from_controller.arready = 1'b1;
    assign from_controller.rid     = '0;
    assign from_controller.rdata   = '0;
    assign from_controller.rresp   = RESP_SLVERR;
    assign from_controller.rlast   = 1'b1;
    assign from_controller.ruser   = '0;
    assign from_controller.rvalid  = from_controller.arvalid;

endmodule : axi4_intf_peripheral_term


// Controller termination (drives idle)
module axi4_intf_controller_term (
    axi4_intf.controller to_peripheral
);
    import axi4_pkg::*;

    assign to_peripheral.awid     = '0;
    assign to_peripheral.awaddr   = '0;
    assign to_peripheral.awlen    = 8'h0;
    assign to_peripheral.awsize   = SIZE_4BYTES;
    assign to_peripheral.awburst  = BURST_INCR;
    assign to_peripheral.awlock   = LOCK_NORMAL;
    assign to_peripheral.awcache  = '0;
    assign to_peripheral.awprot   = '0;
    assign to_peripheral.awqos    = '0;
    assign to_peripheral.awregion = '0;
    assign to_peripheral.awuser   = '0;
    assign to_peripheral.awvalid  = 1'b0;

    assign to_peripheral.wdata    = '0;
    assign to_peripheral.wstrb    = '1;
    assign to_peripheral.wlast    = 1'b0;
    assign to_peripheral.wuser    = '0;
    assign to_peripheral.wvalid   = 1'b0;

    assign to_peripheral.bready   = 1'b0;

    assign to_peripheral.arid     = '0;
    assign to_peripheral.araddr   = '0;
    assign to_peripheral.arlen    = 8'h0;
    assign to_peripheral.arsize   = SIZE_4BYTES;
    assign to_peripheral.arburst  = BURST_INCR;
    assign to_peripheral.arlock   = LOCK_NORMAL;
    assign to_peripheral.arcache  = '0;
    assign to_peripheral.arprot   = '0;
    assign to_peripheral.arqos    = '0;
    assign to_peripheral.arregion = '0;
    assign to_peripheral.aruser   = '0;
    assign to_peripheral.arvalid  = 1'b0;

    assign to_peripheral.rready   = 1'b0;

endmodule : axi4_intf_controller_term


// Collect flat signals (from controller) into axi4_intf (to peripheral)
module axi4_intf_from_signals
    import axi4_pkg::*;
#(
    parameter int DATA_BYTE_WID = 8,
    parameter int ADDR_WID      = 32,
    parameter int ID_WID        = 1,
    parameter int USER_WID      = 1
) (
    input  logic                          aclk,
    // Write address
    input  logic [ID_WID-1:0]             awid,
    input  logic [ADDR_WID-1:0]           awaddr,
    input  logic [7:0]                    awlen,
    input  logic [2:0]                    awsize,
    input  logic [1:0]                    awburst,
    input  logic                          awlock,
    input  logic [3:0]                    awcache,
    input  logic [2:0]                    awprot,
    input  logic [3:0]                    awqos,
    input  logic [3:0]                    awregion,
    input  logic [USER_WID-1:0]           awuser,
    input  logic                          awvalid,
    output logic                          awready,
    // Write data
    input  logic [DATA_BYTE_WID-1:0][7:0] wdata,
    input  logic [DATA_BYTE_WID-1:0]      wstrb,
    input  logic                          wlast,
    input  logic [USER_WID-1:0]           wuser,
    input  logic                          wvalid,
    output logic                          wready,
    // Write response
    output logic [ID_WID-1:0]             bid,
    output logic [1:0]                    bresp,
    output logic [USER_WID-1:0]           buser,
    output logic                          bvalid,
    input  logic                          bready,
    // Read address
    input  logic [ID_WID-1:0]             arid,
    input  logic [ADDR_WID-1:0]           araddr,
    input  logic [7:0]                    arlen,
    input  logic [2:0]                    arsize,
    input  logic [1:0]                    arburst,
    input  logic                          arlock,
    input  logic [3:0]                    arcache,
    input  logic [2:0]                    arprot,
    input  logic [3:0]                    arqos,
    input  logic [3:0]                    arregion,
    input  logic [USER_WID-1:0]           aruser,
    input  logic                          arvalid,
    output logic                          arready,
    // Read data
    output logic [ID_WID-1:0]             rid,
    output logic [DATA_BYTE_WID-1:0][7:0] rdata,
    output logic [1:0]                    rresp,
    output logic                          rlast,
    output logic [USER_WID-1:0]           ruser,
    output logic                          rvalid,
    input  logic                          rready,

    // Interface output (to peripheral)
    axi4_intf.controller                  axi4_if
);
    initial begin
        std_pkg::param_check(axi4_if.DATA_BYTE_WID, DATA_BYTE_WID, "axi4_if.DATA_BYTE_WID");
        std_pkg::param_check(axi4_if.ADDR_WID,      ADDR_WID,      "axi4_if.ADDR_WID");
        std_pkg::param_check(axi4_if.ID_WID,        ID_WID,        "axi4_if.ID_WID");
        std_pkg::param_check(axi4_if.USER_WID,      USER_WID,      "axi4_if.USER_WID");
    end

    assign axi4_if.awid     = awid;
    assign axi4_if.awaddr   = awaddr;
    assign axi4_if.awlen    = awlen;
    assign axi4_if.awsize   = awsize;
    assign axi4_if.awburst  = awburst;
    assign axi4_if.awlock   = awlock;
    assign axi4_if.awcache  = awcache;
    assign axi4_if.awprot   = awprot;
    assign axi4_if.awqos    = awqos;
    assign axi4_if.awregion = awregion;
    assign axi4_if.awuser   = awuser;
    assign axi4_if.awvalid  = awvalid;
    assign awready          = axi4_if.awready;

    assign axi4_if.wdata    = wdata;
    assign axi4_if.wstrb    = wstrb;
    assign axi4_if.wlast    = wlast;
    assign axi4_if.wuser    = wuser;
    assign axi4_if.wvalid   = wvalid;
    assign wready           = axi4_if.wready;

    assign bid              = axi4_if.bid;
    assign bresp            = axi4_if.bresp;
    assign buser            = axi4_if.buser;
    assign bvalid           = axi4_if.bvalid;
    assign axi4_if.bready   = bready;

    assign axi4_if.arid     = arid;
    assign axi4_if.araddr   = araddr;
    assign axi4_if.arlen    = arlen;
    assign axi4_if.arsize   = arsize;
    assign axi4_if.arburst  = arburst;
    assign axi4_if.arlock   = arlock;
    assign axi4_if.arcache  = arcache;
    assign axi4_if.arprot   = arprot;
    assign axi4_if.arqos    = arqos;
    assign axi4_if.arregion = arregion;
    assign axi4_if.aruser   = aruser;
    assign axi4_if.arvalid  = arvalid;
    assign arready          = axi4_if.arready;

    assign rid              = axi4_if.rid;
    assign rdata            = axi4_if.rdata;
    assign rresp            = axi4_if.rresp;
    assign rlast            = axi4_if.rlast;
    assign ruser            = axi4_if.ruser;
    assign rvalid           = axi4_if.rvalid;
    assign axi4_if.rready   = rready;

endmodule : axi4_intf_from_signals
