// =============================================================================
//  NOTICE: This computer software was prepared by The Regents of the
//  University of California through Lawrence Berkeley National Laboratory
//  and Jonathan Sewter hereinafter the Contractor, under Contract No.
//  DE-AC02-05CH11231 with the Department of Energy (DOE). All rights in the
//  computer software are reserved by DOE on behalf of the United States
//  Government and the Contractor as provided in the Contract. You are
//  authorized to use this computer software for Governmental purposes but it
//  is not to be released or distributed to the public.
//
//  NEITHER THE GOVERNMENT NOR THE CONTRACTOR MAKES ANY WARRANTY, EXPRESS OR
//  IMPLIED, OR ASSUMES ANY LIABILITY FOR THE USE OF THIS SOFTWARE.
//
//  This notice including this sentence must appear on any copies of this
//  computer software.
// =============================================================================

module axi4l_decoder #(
    parameter mem_map_pkg::map_spec_t MEM_MAP = mem_map_pkg::DEFAULT_MAP_SPEC
) (
    axi4l_intf.peripheral axi4l_if,
    axi4l_intf.controller axi4l_client_if [MEM_MAP.NUM_REGIONS]
);

    // --------------------
    // Imports
    // --------------------
    import axi4l_pkg::*;

    // --------------------
    // Parameters
    // --------------------
    localparam int ADDR_WID = axi4l_if.ADDR_WID;
    localparam axi4l_bus_width_t BUS_WIDTH = axi4l_if.BUS_WIDTH;
    localparam int DATA_BYTE_WID = get_axi4l_bus_width_in_bytes(BUS_WIDTH);
    localparam int DATA_WID = DATA_BYTE_WID*8;

    localparam int NUM_CLIENTS = MEM_MAP.NUM_REGIONS;
    localparam int CLIENT_SEL_WID = NUM_CLIENTS > 1 ? $clog2(NUM_CLIENTS) : 1;

    // --------------------
    // Signals
    // --------------------
    // AXI-L peripheral termination
    logic                      clk;
    logic                      srst;

    logic                      wr;
    logic [ADDR_WID-1:0]       wr_addr;
    logic [DATA_WID-1:0]       wr_data;
    logic [DATA_BYTE_WID-1:0]  wr_strb;
    logic                      wr_ack;
    resp_t                     wr_resp;

    logic                      rd;
    logic [ADDR_WID-1:0]       rd_addr;
    logic [DATA_WID-1:0]       rd_data;
    logic                      rd_ack;
    resp_t                     rd_resp;

    // Decoder internal signals
    logic                      __wr;
    logic                      __wr_ack;
    resp_t                     __wr_resp;
    logic                      __wr_addr_decode_error;

    logic                      __rd;
    logic                      __rd_ack;
    resp_t                     __rd_resp;
    logic [DATA_WID-1:0]       __rd_data;
    logic                      __rd_addr_decode_error;

    logic [CLIENT_SEL_WID-1:0] client_wr_sel;
    logic [ADDR_WID-1:0]       client_wr_offset;
    logic                      client_wready [NUM_CLIENTS];
    logic                      client_awready[NUM_CLIENTS];
    logic                      client_bvalid [NUM_CLIENTS];
    resp_t                     client_bresp  [NUM_CLIENTS];
    logic                      client_wr_pending_sel_vec [NUM_CLIENTS];

    logic [CLIENT_SEL_WID-1:0] client_rd_sel;
    logic [ADDR_WID-1:0]       client_rd_offset;
    logic                      client_arready[NUM_CLIENTS];
    logic                      client_rvalid [NUM_CLIENTS];
    resp_t                     client_rresp  [NUM_CLIENTS];
    logic [DATA_WID-1:0]       client_rdata  [NUM_CLIENTS];
    logic                      client_rd_pending_sel_vec [NUM_CLIENTS];

    // --------------------
    // Interfaces
    // --------------------
    axi4l_intf #(.ADDR_WID(axi4l_if.ADDR_WID), .BUS_WIDTH(axi4l_if.BUS_WIDTH)) __axil_if ();

    // --------------------------------------------------------
    // RTL
    // --------------------------------------------------------
    // Terminate upstream (controller) AXI-L interface
    axi4l_peripheral #(
        .ADDR_WID  ( ADDR_WID ),
        .BUS_WIDTH ( BUS_WIDTH )
    ) i_axi4l_peripheral (
        // Upstream AXI-L
        .axi4l_if  ( axi4l_if ),
        // Downstream register access
        .clk       ( clk ),  // Output
        .srst      ( srst ), // Output
        .wr        ( wr ),
        .wr_addr   ( wr_addr ),
        .wr_data   ( wr_data ),
        .wr_strb   ( wr_strb ),
        .wr_ack    ( wr_ack ),
        .wr_resp   ( wr_resp ),
        .rd        ( rd ),
        .rd_addr   ( rd_addr ),
        .rd_data   ( rd_data ),
        .rd_ack    ( rd_ack ),
        .rd_resp   ( rd_resp )
    );

    // Address Decoding
    // ----------------
    // : Write address decode
    always_comb begin
        client_wr_sel = 0;
        client_wr_offset = 0;
        __wr_addr_decode_error = 1'b0;
        if (wr) mem_map_pkg::decode(wr_addr, MEM_MAP, client_wr_sel, client_wr_offset, __wr_addr_decode_error);
    end
    assign __wr = wr && !__wr_addr_decode_error;

    // : Read address decode
    always_comb begin
        client_rd_sel = 0;
        client_rd_offset = 0;
        __rd_addr_decode_error = 1'b0;
        if (rd) mem_map_pkg::decode(rd_addr, MEM_MAP, client_rd_sel, client_rd_offset, __rd_addr_decode_error);
    end
    assign __rd = rd && !__rd_addr_decode_error;

    // Terminate downstream (peripheral) AXI-L interfaces
    axi4l_controller #(
        .ADDR_WID  ( ADDR_WID ),
        .BUS_WIDTH ( BUS_WIDTH )
    ) i_axi4l_controller (
        .clk       ( clk ), // Input
        .srst      ( srst ), // Input
        .wr        ( __wr ),
        .wr_addr   ( client_wr_offset ),
        .wr_data   ( wr_data ),
        .wr_strb   ( wr_strb ),
        .wr_ack    ( __wr_ack ),
        .wr_resp   ( __wr_resp ),
        .rd        ( __rd ),
        .rd_addr   ( client_rd_offset ),
        .rd_data   ( __rd_data ),
        .rd_ack    ( __rd_ack ),
        .rd_resp   ( __rd_resp ),
        // Downstream (AXI-L)
        .axi4l_if  ( __axil_if )
    );

    // Write response
    initial begin
        wr_ack = 1'b0;
        wr_resp = RESP_SLVERR;
    end
    always @(posedge clk) begin
        if (srst) begin
            wr_ack  <= 1'b0;
            wr_resp <= RESP_SLVERR;
        end else begin
            if (__wr_addr_decode_error) begin
                wr_ack  <= 1'b1;
                wr_resp <= RESP_DECERR;
            end else if (__wr_ack) begin
                wr_ack  <= 1'b1;
                wr_resp <= __wr_resp;
            end else begin
                wr_ack  <= 1'b0;
                wr_resp <= RESP_SLVERR;
            end
        end
    end

    // Read data
    always_ff @(posedge clk) begin
        if (__rd_addr_decode_error) rd_data <= reg_pkg::BAD_ACCESS_DATA;
        else                        rd_data <= __rd_data;
    end

    // Read response
    initial begin
        rd_ack  = 1'b0;
        rd_resp = RESP_SLVERR;
    end
    always @(posedge clk) begin
        if (srst) begin
            rd_ack  <= 1'b0;
            rd_resp <= RESP_SLVERR;
        end else begin
            if (__rd_addr_decode_error) begin
                rd_ack  <= 1'b1;
                rd_resp <= RESP_DECERR;
            end else if (__rd_ack) begin
                rd_ack  <= 1'b1;
                rd_resp <= __rd_resp;
            end else begin
                rd_ack  <= 1'b0;
                rd_resp <= RESP_SLVERR;
            end
        end
    end

    // Write fanout to clients
    // -----------------------
    // Latch client select
    initial client_wr_pending_sel_vec = '{NUM_CLIENTS{1'b0}};
    always @(posedge clk) begin
        if (srst) client_wr_pending_sel_vec <= '{NUM_CLIENTS{1'b0}};
        else begin
            if (wr) begin
                for (int i = 0; i < NUM_CLIENTS; i++) begin
                    client_wr_pending_sel_vec[i] <= (client_wr_sel == i);
                end
            end
        end
    end

    generate
        for (genvar g_client = 0; g_client < NUM_CLIENTS; g_client++) begin : g__client
            // (Local) signals
            (* dont_touch = "true" *) logic __aresetn;
            // Individually pipeline reset to peripherals
            initial __aresetn = 1'b0;
            always @(posedge clk) __aresetn <= !srst;
            // Clock/reset
            assign axi4l_client_if[g_client].aclk = clk;
            assign axi4l_client_if[g_client].aresetn = __aresetn;
            // Write address
            assign axi4l_client_if[g_client].awvalid = __axil_if.awvalid && client_wr_pending_sel_vec[g_client];
            assign axi4l_client_if[g_client].awaddr = __axil_if.awaddr;
            assign axi4l_client_if[g_client].awprot = 0;
            // Write data
            assign axi4l_client_if[g_client].wvalid = __axil_if.wvalid && client_wr_pending_sel_vec[g_client];
            assign axi4l_client_if[g_client].wdata = __axil_if.wdata;
            assign axi4l_client_if[g_client].wstrb = __axil_if.wstrb;
            // Write response
            assign axi4l_client_if[g_client].bready = client_wr_pending_sel_vec[g_client];
            assign client_awready [g_client] = axi4l_client_if[g_client].awready;
            assign client_wready  [g_client] = axi4l_client_if[g_client].wready;
            assign client_bvalid  [g_client] = axi4l_client_if[g_client].bvalid;
            assign client_bresp   [g_client] = axi4l_client_if[g_client].bresp;
        end
    endgenerate

    // Mux client write ready signals
    always_comb begin
        __axil_if.awready = 1'b0;
        __axil_if.wready = 1'b0;
        for (int i = 0; i < NUM_CLIENTS; i++) begin
            if (client_wr_pending_sel_vec[i]) begin
                __axil_if.awready = client_awready[i];
                __axil_if.wready = client_wready[i];
            end
        end
    end

    // Write response mux
    // ------------------
    always_comb begin
        __axil_if.bvalid = 1'b0;
        __axil_if.bresp = RESP_SLVERR;
        for (int i = 0; i < NUM_CLIENTS; i++) begin
            if (client_wr_pending_sel_vec[i]) begin
                __axil_if.bvalid = client_bvalid[i];
                __axil_if.bresp = client_bresp[i];
            end
        end
    end

    // Read fanout to clients
    // ----------------------
    // Latch client select
    initial client_rd_pending_sel_vec = '{NUM_CLIENTS{1'b0}};
    always @(posedge clk) begin
        if (srst) client_rd_pending_sel_vec <= '{NUM_CLIENTS{1'b0}};
        else begin
            if (rd) begin
                for (int i = 0; i < NUM_CLIENTS; i++) begin
                    client_rd_pending_sel_vec[i] <= (client_rd_sel == i);
                end
            end
        end
    end

    generate
        for (genvar g_client = 0; g_client < NUM_CLIENTS; g_client++) begin : g__client_rd
            // Read address
            assign axi4l_client_if[g_client].arvalid = __axil_if.arvalid && client_rd_pending_sel_vec[g_client];
            assign axi4l_client_if[g_client].araddr = __axil_if.araddr;
            assign axi4l_client_if[g_client].arprot = 0;
            // Read data
            assign axi4l_client_if[g_client].rready = client_rd_pending_sel_vec[g_client];
            assign client_arready[g_client] = axi4l_client_if[g_client].arready;
            assign client_rvalid [g_client] = axi4l_client_if[g_client].rvalid;
            assign client_rresp  [g_client] = axi4l_client_if[g_client].rresp;
            assign client_rdata  [g_client] = axi4l_client_if[g_client].rdata;
        end : g__client_rd
    endgenerate

    // Mux client read ready signals
    always_comb begin
        __axil_if.arready = 1'b0;
        for (int i = 0; i < NUM_CLIENTS; i++) begin
            if (client_rd_pending_sel_vec[i]) __axil_if.arready = client_arready[i];
        end
    end

    // Read response mux
    // -----------------
    always_comb begin
        __axil_if.rvalid = 1'b0;
        __axil_if.rresp = RESP_SLVERR;
        __axil_if.rdata = 0;
        for (int i = 0; i < NUM_CLIENTS; i++) begin
            if (client_rd_pending_sel_vec[i]) begin
                __axil_if.rvalid  = client_rvalid[i];
                __axil_if.rresp = client_rresp[i];
                __axil_if.rdata = client_rdata[i];
            end
        end
    end

endmodule : axi4l_decoder
