interface axi4l_intf
    import axi4l_pkg::*;
#(
    parameter int ADDR_WID = 32,
    parameter axi4l_bus_width_t BUS_WIDTH = AXI4L_BUS_WIDTH_32
);
    // Derived parameters
    localparam int DATA_BYTE_WID = get_axi4l_bus_width_in_bytes(BUS_WIDTH);
    localparam int DATA_WID = DATA_BYTE_WID * 8;

    // (Local) parameters
    localparam int DEFAULT_WR_TIMEOUT = 256; // Default write timeout (in ACLK cycles)
    localparam int DEFAULT_RD_TIMEOUT = 256; // Read timeout (in ACLK cycles)

    // Signals
    logic                     aclk;
    logic                     aresetn;
    // -- Write address
    logic                     awvalid;
    logic                     awready;
    logic [ADDR_WID-1:0]      awaddr;
    logic [2:0]               awprot;
    // -- Write data
    logic                     wvalid;
    logic                     wready;
    logic [DATA_WID-1:0]      wdata;
    logic [DATA_BYTE_WID-1:0] wstrb;
    // -- Write response
    logic                     bvalid;
    logic                     bready;
    resp_t                    bresp;
    // -- Read address
    logic                     arvalid;
    logic                     arready;
    logic [ADDR_WID-1:0]      araddr;
    logic [2:0]               arprot;
    // -- Read data
    logic                     rvalid;
    logic                     rready;
    logic [DATA_WID-1:0]      rdata;
    resp_t                    rresp;

    // Modports
    modport controller (
        output aclk,
        output aresetn,
        output awvalid,
        input  awready,
        output awaddr,
        output awprot,
        output wvalid,
        input  wready,
        output wdata,
        output wstrb,
        input  bvalid,
        output bready,
        input  bresp,
        output arvalid,
        input  arready,
        output araddr,
        output arprot,
        input  rvalid,
        output rready,
        input  rdata,
        input  rresp
    );

    modport peripheral (
        input  aclk,
        input  aresetn,
        input  awvalid,
        output awready,
        input  awaddr,
        input  awprot,
        input  wvalid,
        output wready,
        input  wdata,
        input  wstrb,
        output bvalid,
        input  bready,
        output bresp,
        input  arvalid,
        output arready,
        input  araddr,
        input  arprot,
        output rvalid,
        input  rready,
        output rdata,
        output rresp
    );

    clocking cb @(posedge aclk);
        default input #1step output #1step;
        output awaddr, awprot, wdata, wstrb, araddr, arprot;
        input  awready, wready, bvalid, bresp, arready, rvalid, rdata, rresp;
        inout  awvalid, wvalid, bready, arvalid, rready;
    endclocking

    task idle_controller();
        cb.awvalid <= 1'b0;
        cb.awaddr  <=   '0;
        cb.awprot  <= 3'h0;
        cb.wvalid  <= 1'b0;
        cb.wstrb   <=   '0;
        cb.wdata   <=   '0;
        cb.bready  <= 1'b0;
        cb.arvalid <= 1'b0;
        cb.araddr  <=   '0;
        cb.arprot  <= 3'h0;
        cb.rready  <= 1'b0;
        @(cb);
    endtask

    task _wait(input int cycles);
        repeat (cycles) @(cb);
    endtask

    task _read(
            input  bit [ADDR_WID-1:0] addr,
            output bit [DATA_WID-1:0] data,
            output resp_t             resp
        );
        cb.araddr  <= addr;
        cb.rready  <= 1'b0;
        cb.arvalid <= 1'b1;
        @(cb);
        wait(cb.arvalid && cb.arready);
        cb.arvalid <= 1'b0;
        cb.araddr <= 'x;
        cb.rready <= 1'b1;
        @(cb);
        wait(cb.rvalid && cb.rready);
        cb.rready <= 1'b0;
        resp = cb.rresp;
        data = cb.rdata;
    endtask

    task read(
            input  bit [ADDR_WID-1:0] addr,
            output bit [DATA_WID-1:0] data,
            output resp_t             resp,
            output bit                timeout,
            input  int RD_TIMEOUT = DEFAULT_RD_TIMEOUT
        );
        resp = axi4l_pkg::RESP_SLVERR;
        fork
            begin
                fork
                    begin
                        timeout = 1'b0;
                        _read(addr, data, resp);
                    end
                    begin
                        if (RD_TIMEOUT > 0) begin
                            _wait(RD_TIMEOUT);
                            timeout = 1'b1;
                        end else forever _wait(1);
                    end
                join_any
                disable fork;
            end
        join
        if (timeout) idle_controller();
    endtask

    task read_byte(
            input  bit [ADDR_WID-1:0] addr,
            output byte               data,
            output resp_t             resp,
            output bit                timeout,
            input  int RD_TIMEOUT = DEFAULT_RD_TIMEOUT
        );
        bit [ADDR_WID-1:0]           addr_aligned;
        bit [DATA_BYTE_WID-1:0][7:0] data_shifted;
        int                          byte_pos;

        addr_aligned = (addr / DATA_BYTE_WID) * DATA_BYTE_WID;
        byte_pos = addr % DATA_BYTE_WID;

        read(addr_aligned, data_shifted, resp, timeout, RD_TIMEOUT);

        data = data_shifted[byte_pos];
    endtask

    task _write(
            input  bit [ADDR_WID-1:0]      addr,
            input  bit [DATA_WID-1:0]      data,
            input  bit [DATA_BYTE_WID-1:0] strb,
            output resp_t                  resp,
            input  bit  RANDOMIZE_AW_W_ALIGNMENT = 1'b0
        );
        fork
            begin
                if (RANDOMIZE_AW_W_ALIGNMENT) repeat($urandom % 3) @(cb);
                // Write address transaction
                cb.awvalid <= 1'b1;
                cb.awaddr <= addr;
                @(cb);
                wait (cb.awvalid && cb.awready);
                cb.awvalid <= 1'b0;
                cb.awaddr <= 'x;
            end
            begin
                if (RANDOMIZE_AW_W_ALIGNMENT) repeat($urandom % 3) @(cb);
                // Write data transaction
                cb.wvalid <= 1'b1;
                cb.wdata <= data;
                cb.wstrb <= strb;
                @(cb);
                wait (cb.wvalid && cb.wready);
                cb.wvalid <= 1'b0;
                cb.wdata <= 'x;
                cb.wstrb <= 'x;
            end
        join
        // Write response transaction
        cb.bready <= 1'b1;
        @(cb);
        wait(cb.bvalid && cb.bready);
        cb.bready <= 1'b0;
        resp = cb.bresp;
    endtask

    task _write_safe(
            input  bit [ADDR_WID-1:0]      addr,
            input  bit [DATA_WID-1:0]      data,
            input  bit [DATA_BYTE_WID-1:0] strb,
            output resp_t                  resp,
            output bit                     timeout,
            input  int WR_TIMEOUT = DEFAULT_WR_TIMEOUT,
            input  bit RANDOMIZE_AW_W_ALIGNMENT = 1'b0
        );
        resp = axi4l_pkg::RESP_SLVERR;
        fork
            begin
                fork
                    begin
                        timeout = 1'b0;
                        _write(addr, data, strb, resp, RANDOMIZE_AW_W_ALIGNMENT);
                    end
                    begin
                        if (WR_TIMEOUT > 0) begin
                            _wait(WR_TIMEOUT);
                            timeout = 1'b1;
                        end else forever _wait(1);
                    end
                join_any
                disable fork;
            end
        join
        if (timeout) idle_controller();
    endtask

    task write(
            input  bit [ADDR_WID-1:0] addr,
            input  bit [DATA_WID-1:0] data,
            output resp_t             resp,
            output bit                timeout,
            input  int WR_TIMEOUT = DEFAULT_WR_TIMEOUT,
            input  bit RANDOMIZE_AW_W_ALIGNMENT = 1'b0
        );
        _write_safe(addr, data, '1, resp, timeout, WR_TIMEOUT, RANDOMIZE_AW_W_ALIGNMENT);
    endtask

    task write_byte(
            input  bit [ADDR_WID-1:0] addr,
            input  byte               data,
            output resp_t             resp,
            output bit                timeout,
            input  int WR_TIMEOUT = DEFAULT_WR_TIMEOUT
        );
        bit [ADDR_WID-1:0]      addr_aligned;
        bit [DATA_WID-1:0]      data_shifted;
        bit [DATA_BYTE_WID-1:0] strb;
        int                     byte_pos;
        addr_aligned = (addr / DATA_BYTE_WID) * DATA_BYTE_WID;
        byte_pos = addr % DATA_BYTE_WID;

        // Shift byte into proper byte lane and set strobe signal
        strb = 1'b1 << byte_pos;
        data_shifted = data << byte_pos*8;

        _write_safe(addr_aligned, data_shifted, strb, resp, timeout, WR_TIMEOUT);
    endtask

endinterface : axi4l_intf

// AXI4-Lite (back-to-back) connector helper module
module axi4l_intf_connector (
    axi4l_intf.peripheral axi4l_if_from_controller,
    axi4l_intf.controller axi4l_if_to_peripheral
);
    // Connect signals (controller -> peripheral)
    assign axi4l_if_to_peripheral.aclk = axi4l_if_from_controller.aclk;
    assign axi4l_if_to_peripheral.aresetn = axi4l_if_from_controller.aresetn;
    assign axi4l_if_to_peripheral.awvalid = axi4l_if_from_controller.awvalid;
    assign axi4l_if_to_peripheral.awaddr = axi4l_if_from_controller.awaddr;
    assign axi4l_if_to_peripheral.awprot = axi4l_if_from_controller.awprot;
    assign axi4l_if_to_peripheral.wvalid = axi4l_if_from_controller.wvalid;
    assign axi4l_if_to_peripheral.wdata = axi4l_if_from_controller.wdata;
    assign axi4l_if_to_peripheral.wstrb = axi4l_if_from_controller.wstrb;
    assign axi4l_if_to_peripheral.bready = axi4l_if_from_controller.bready;
    assign axi4l_if_to_peripheral.arvalid = axi4l_if_from_controller.arvalid;
    assign axi4l_if_to_peripheral.araddr = axi4l_if_from_controller.araddr;
    assign axi4l_if_to_peripheral.arprot = axi4l_if_from_controller.arprot;
    assign axi4l_if_to_peripheral.rready = axi4l_if_from_controller.rready;

    // Connect signals (peripheral -> controller)
    assign axi4l_if_from_controller.awready = axi4l_if_to_peripheral.awready;
    assign axi4l_if_from_controller.wready = axi4l_if_to_peripheral.wready;
    assign axi4l_if_from_controller.bvalid = axi4l_if_to_peripheral.bvalid;
    assign axi4l_if_from_controller.bresp = axi4l_if_to_peripheral.bresp;
    assign axi4l_if_from_controller.arready = axi4l_if_to_peripheral.arready;
    assign axi4l_if_from_controller.rvalid = axi4l_if_to_peripheral.rvalid;
    assign axi4l_if_from_controller.rdata = axi4l_if_to_peripheral.rdata;
    assign axi4l_if_from_controller.rresp = axi4l_if_to_peripheral.rresp;

endmodule : axi4l_intf_connector


// AXI4-Lite peripheral termination helper module
module axi4l_intf_peripheral_term
    import axi4l_pkg::*;
(
    axi4l_intf.peripheral axi4l_if
);
    // Tie off peripheral outputs
    assign axi4l_if.awready = 1'b0;
    assign axi4l_if.wready = 1'b0;
    assign axi4l_if.bvalid = 1'b0;
    assign axi4l_if.bresp = RESP_OKAY;
    assign axi4l_if.arready = 1'b0;
    assign axi4l_if.rvalid = 1'b0;
    assign axi4l_if.rdata = '0;
    assign axi4l_if.rresp = RESP_OKAY;
endmodule : axi4l_intf_peripheral_term


// AXI4-Lite controller termination helper module
module axi4l_intf_controller_term (
    axi4l_intf.controller axi4l_if
);
    // Tie off controller outputs
    assign axi4l_if.aclk = 1'b0;
    assign axi4l_if.aresetn = 1'b0;
    assign axi4l_if.awvalid = 1'b0;
    assign axi4l_if.awaddr = '0;
    assign axi4l_if.awprot = 3'h0;
    assign axi4l_if.wvalid = 1'b0;
    assign axi4l_if.wdata = '0;
    assign axi4l_if.wstrb = '0;
    assign axi4l_if.bready = 1'b0;
    assign axi4l_if.arvalid = 1'b0;
    assign axi4l_if.araddr = '0;
    assign axi4l_if.arprot = 3'h0;
    assign axi4l_if.rready = 1'b0;
endmodule : axi4l_intf_controller_term


// Collect flattened AXI-L signals (from controller) into interface (to peripheral)
module axi4l_intf_from_signals
    import axi4l_pkg::*;
#(
    parameter int ADDR_WID = 32,
    parameter axi4l_bus_width_t BUS_WIDTH = AXI4L_BUS_WIDTH_32,
    // Derived parameters (don't override)
    parameter int DATA_BYTE_WID = get_axi4l_bus_width_in_bytes(BUS_WIDTH),
    parameter int DATA_WID = DATA_BYTE_WID * 8
) (
    // Signals (from controller)
    input  logic                     aclk,
    input  logic                     aresetn,
    input  logic                     awvalid,
    output logic                     awready,
    input  logic [ADDR_WID-1:0]      awaddr,
    input  logic [2:0]               awprot,
    input  logic                     wvalid,
    output logic                     wready,
    input  logic [DATA_WID-1:0]      wdata,
    input  logic [DATA_BYTE_WID-1:0] wstrb,
    output logic                     bvalid,
    input  logic                     bready,
    output logic [1:0]               bresp,
    input  logic                     arvalid,
    output logic                     arready,
    input  logic [ADDR_WID-1:0]      araddr,
    input  logic [2:0]               arprot,
    output logic                     rvalid,
    input  logic                     rready,
    output logic [DATA_WID-1:0]      rdata,
    output logic [1:0]               rresp,

    // Interface (to peripheral)
    axi4l_intf.controller            axi4l_if
);

    // Connect signals to interface (controller -> peripheral)
    assign axi4l_if.aclk    = aclk;
    assign axi4l_if.aresetn = aresetn;
    assign axi4l_if.awvalid = awvalid;
    assign axi4l_if.awaddr  = awaddr;
    assign axi4l_if.awprot  = awprot;
    assign axi4l_if.wvalid  = wvalid;
    assign axi4l_if.wdata   = wdata;
    assign axi4l_if.wstrb   = wstrb;
    assign axi4l_if.bready  = bready;
    assign axi4l_if.arvalid = arvalid;
    assign axi4l_if.araddr  = araddr;
    assign axi4l_if.arprot  = arprot;
    assign axi4l_if.rready  = rready;

    // Connect interface to signals (controller -> peripheral)
    assign awready = axi4l_if.awready;
    assign wready  = axi4l_if.wready;
    assign bvalid  = axi4l_if.bvalid;
    assign bresp   = axi4l_if.bresp;
    assign arready = axi4l_if.arready;
    assign rvalid  = axi4l_if.rvalid;
    assign rdata   = axi4l_if.rdata;
    assign rresp   = axi4l_if.rresp;

endmodule : axi4l_intf_from_signals


// Break interface (from controller) into flattened AXI-L signals (to controller)
module axi4l_intf_to_signals
    import axi4l_pkg::*;
#(
    parameter int ADDR_WID = 32,
    parameter axi4l_bus_width_t BUS_WIDTH = AXI4L_BUS_WIDTH_32,
    // Derived parameters (don't override)
    parameter int DATA_BYTE_WID = get_axi4l_bus_width_in_bytes(BUS_WIDTH),
    parameter int DATA_WID = DATA_BYTE_WID * 8
) (
    // Interface (from controller)
    axi4l_intf.peripheral            axi4l_if,

    // Signals (to peripheral)
    output logic                     aclk,
    output logic                     aresetn,
    output logic                     awvalid,
    input  logic                     awready,
    output logic [ADDR_WID-1:0]      awaddr,
    output logic [2:0]               awprot,
    output logic                     wvalid,
    input  logic                     wready,
    output logic [DATA_WID-1:0]      wdata,
    output logic [DATA_BYTE_WID-1:0] wstrb,
    input  logic                     bvalid,
    output logic                     bready,
    input  resp_t                    bresp,
    output logic                     arvalid,
    input  logic                     arready,
    output logic [ADDR_WID-1:0]      araddr,
    output logic [2:0]               arprot,
    input  logic                     rvalid,
    output logic                     rready,
    input  logic [DATA_WID-1:0]      rdata,
    input  resp_t                    rresp
);

    // Connect interface to signals (controller -> peripheral)
    assign aclk    = axi4l_if.aclk;
    assign aresetn = axi4l_if.aresetn;
    assign awvalid = axi4l_if.awvalid;
    assign awaddr  = axi4l_if.awaddr;
    assign awprot  = axi4l_if.awprot;
    assign wvalid  = axi4l_if.wvalid;
    assign wdata   = axi4l_if.wdata;
    assign wstrb   = axi4l_if.wstrb;
    assign bready  = axi4l_if.bready;
    assign arvalid = axi4l_if.arvalid;
    assign araddr  = axi4l_if.araddr;
    assign arprot  = axi4l_if.arprot;
    assign rready  = axi4l_if.rready;

    // Connect signals to interface (controller -> peripheral)
    assign axi4l_if.awready = awready;
    assign axi4l_if.wready  = wready;
    assign axi4l_if.bvalid  = bvalid;
    assign axi4l_if.bresp   = bresp;
    assign axi4l_if.arready = arready;
    assign axi4l_if.rvalid  = rvalid;
    assign axi4l_if.rdata   = rdata;
    assign axi4l_if.rresp   = rresp;

endmodule : axi4l_intf_to_signals


module axi4l_intf_cdc
    import axi4l_pkg::*;
#(
    parameter int ADDR_WID = 32,
    parameter axi4l_bus_width_t BUS_WIDTH = AXI4L_BUS_WIDTH_32,
    // Derived parameters (don't override)
    parameter int DATA_BYTE_WID = get_axi4l_bus_width_in_bytes(BUS_WIDTH),
    parameter int DATA_WID = DATA_BYTE_WID * 8
) (
    axi4l_intf.peripheral axi4l_if_from_controller,
    input logic           clk_to_peripheral,
    axi4l_intf.controller axi4l_if_to_peripheral
);

    assign axi4l_if_to_peripheral.aclk = clk_to_peripheral;

    sync_reset #(
        .OUTPUT_ACTIVE_LOW ( 1 ) // Default is active-low async input, active-high sync output
    ) i_sync_reset (
        .rst_in   ( axi4l_if_from_controller.aresetn ),
        .clk_out  ( clk_to_peripheral ),
        .srst_out ( axi4l_if_to_peripheral.aresetn )
    );

    // NOTE: Xilinx IP
    //       Has been statically configured for 32-bit address/data bus widths
    axi_clock_converter_0 i_axi_clock_converter_0 (
        .s_axi_aclk   (axi4l_if_from_controller.aclk),     // input wire s_axi_aclk
        .s_axi_aresetn(axi4l_if_from_controller.aresetn),  // input wire s_axi_aresetn
        .s_axi_awaddr (axi4l_if_from_controller.awaddr),   // input wire [31 : 0] s_axi_awaddr
        .s_axi_awprot (axi4l_if_from_controller.awprot),   // input wire [2 : 0] s_axi_awprot
        .s_axi_awvalid(axi4l_if_from_controller.awvalid),  // input wire s_axi_awvalid
        .s_axi_awready(axi4l_if_from_controller.awready),  // output wire s_axi_awready
        .s_axi_wdata  (axi4l_if_from_controller.wdata),    // input wire [31 : 0] s_axi_wdata
        .s_axi_wstrb  (axi4l_if_from_controller.wstrb),    // input wire [3 : 0] s_axi_wstrb
        .s_axi_wvalid (axi4l_if_from_controller.wvalid),   // input wire s_axi_wvalid
        .s_axi_wready (axi4l_if_from_controller.wready),   // output wire s_axi_wready
        .s_axi_bresp  (axi4l_if_from_controller.bresp),    // output wire [1 : 0] s_axi_bresp
        .s_axi_bvalid (axi4l_if_from_controller.bvalid),   // output wire s_axi_bvalid
        .s_axi_bready (axi4l_if_from_controller.bready),   // input wire s_axi_bready
        .s_axi_araddr (axi4l_if_from_controller.araddr),   // input wire [31 : 0] s_axi_araddr
        .s_axi_arprot (axi4l_if_from_controller.arprot),   // input wire [2 : 0] s_axi_arprot
        .s_axi_arvalid(axi4l_if_from_controller.arvalid),  // input wire s_axi_arvalid
        .s_axi_arready(axi4l_if_from_controller.arready),  // output wire s_axi_arready
        .s_axi_rdata  (axi4l_if_from_controller.rdata),    // output wire [31 : 0] s_axi_rdata
        .s_axi_rresp  (axi4l_if_from_controller.rresp),    // output wire [1 : 0] s_axi_rresp
        .s_axi_rvalid (axi4l_if_from_controller.rvalid),   // output wire s_axi_rvalid
        .s_axi_rready (axi4l_if_from_controller.rready),   // input wire s_axi_rready
        .m_axi_aclk   (axi4l_if_to_peripheral.aclk),       // input wire m_axi_aclk
        .m_axi_aresetn(axi4l_if_to_peripheral.aresetn),    // input wire m_axi_aresetn
        .m_axi_awaddr (axi4l_if_to_peripheral.awaddr),     // output wire [31 : 0] m_axi_awaddr
        .m_axi_awprot (axi4l_if_to_peripheral.awprot),     // output wire [2 : 0] m_axi_awprot
        .m_axi_awvalid(axi4l_if_to_peripheral.awvalid),    // output wire m_axi_awvalid
        .m_axi_awready(axi4l_if_to_peripheral.awready),    // input wire m_axi_awready
        .m_axi_wdata  (axi4l_if_to_peripheral.wdata),      // output wire [31 : 0] m_axi_wdata
        .m_axi_wstrb  (axi4l_if_to_peripheral.wstrb),      // output wire [3 : 0] m_axi_wstrb
        .m_axi_wvalid (axi4l_if_to_peripheral.wvalid),     // output wire m_axi_wvalid
        .m_axi_wready (axi4l_if_to_peripheral.wready),     // input wire m_axi_wready
        .m_axi_bresp  (axi4l_if_to_peripheral.bresp),      // input wire [1 : 0] m_axi_bresp
        .m_axi_bvalid (axi4l_if_to_peripheral.bvalid),     // input wire m_axi_bvalid
        .m_axi_bready (axi4l_if_to_peripheral.bready),     // output wire m_axi_bready
        .m_axi_araddr (axi4l_if_to_peripheral.araddr),     // output wire [31 : 0] m_axi_araddr
        .m_axi_arprot (axi4l_if_to_peripheral.arprot),     // output wire [2 : 0] m_axi_arprot
        .m_axi_arvalid(axi4l_if_to_peripheral.arvalid),    // output wire m_axi_arvalid
        .m_axi_arready(axi4l_if_to_peripheral.arready),    // input wire m_axi_arready
        .m_axi_rdata  (axi4l_if_to_peripheral.rdata),      // input wire [31 : 0] m_axi_rdata
        .m_axi_rresp  (axi4l_if_to_peripheral.rresp),      // input wire [1 : 0] m_axi_rresp
        .m_axi_rvalid (axi4l_if_to_peripheral.rvalid),     // input wire m_axi_rvalid
        .m_axi_rready (axi4l_if_to_peripheral.rready)      // output wire m_axi_rready
    );

endmodule : axi4l_intf_cdc

