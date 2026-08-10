`include "svunit_defines.svh"

// Unit test for the vitisnetp4_forward IP.
//
// Verifies that the IP instantiates and resets cleanly, that the VitisNetP4 DPI
// agent initialises without error, and that table-programming operations
// (reset_tables, table_init_from_file) complete successfully.
module vitisnetp4_forward_unit_test;
    import svunit_pkg::svunit_testcase;
    import xilinx_vitisnetp4_example_pkg::*;
    import xilinx_vitisnetp4_verif_pkg::*;
    import vitisnetp4_forward_pkg::*;

    string name = "vitisnetp4_forward_ut";
    svunit_testcase svunit_ut;

    // =========================================================================
    // Parameters (match example IP defaults)
    // =========================================================================
    localparam int TDATA_NUM_BYTES_L = xilinx_vitisnetp4_example_pkg::TDATA_NUM_BYTES;
    localparam int TDATA_WID         = TDATA_NUM_BYTES_L * 8;

    // =========================================================================
    // Clocks and resets
    // =========================================================================
    logic s_axis_aclk;
    `SVUNIT_CLK_GEN(s_axis_aclk, 4ns);

    std_reset_intf #(.ACTIVE_LOW(1)) reset_if (.clk(s_axis_aclk));
    logic s_axis_aresetn;
    assign s_axis_aresetn = reset_if.reset;
    assign reset_if.ready = 1'b1;

    task reset();
        reset_if.pulse(8);
    endtask

    // =========================================================================
    // AXI4-S signals
    // =========================================================================
    logic [TDATA_WID-1:0]           s_axis_tdata;
    logic [TDATA_NUM_BYTES_L-1:0]   s_axis_tkeep;
    logic                           s_axis_tvalid;
    logic                           s_axis_tlast;
    logic                           s_axis_tready;

    logic [TDATA_WID-1:0]           m_axis_tdata;
    logic [TDATA_NUM_BYTES_L-1:0]   m_axis_tkeep;
    logic                           m_axis_tvalid;
    logic                           m_axis_tlast;
    logic                           m_axis_tready;

    // =========================================================================
    // AXI4-Lite signals (driven by exported DPI tasks below)
    // =========================================================================
    localparam int S_AXI_ADDR_WIDTH = 14;

    logic [S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr;
    logic                        s_axi_awvalid;
    logic                        s_axi_awready;
    logic [31:0]                 s_axi_wdata;
    logic  [3:0]                 s_axi_wstrb;
    logic                        s_axi_wvalid;
    logic                        s_axi_wready;
    logic  [1:0]                 s_axi_bresp;
    logic                        s_axi_bvalid;
    logic                        s_axi_bready;
    logic [S_AXI_ADDR_WIDTH-1:0] s_axi_araddr;
    logic                        s_axi_arvalid;
    logic                        s_axi_arready;
    logic [31:0]                 s_axi_rdata;
    logic  [1:0]                 s_axi_rresp;
    logic                        s_axi_rvalid;
    logic                        s_axi_rready;

    logic s_axi_aclk;
    logic s_axi_aresetn;
    `SVUNIT_CLK_GEN(s_axi_aclk, 10ns);
    assign s_axi_aresetn = s_axis_aresetn;

    // =========================================================================
    // CAM memory clock / reset (share data-path clock)
    // =========================================================================
    logic cam_mem_aclk;
    logic cam_mem_aresetn;
    assign cam_mem_aclk    = s_axis_aclk;
    assign cam_mem_aresetn = s_axis_aresetn;

    // =========================================================================
    // User metadata
    // =========================================================================
    localparam int USER_META_DATA_WIDTH = 9;

    logic [USER_META_DATA_WIDTH-1:0] user_metadata_in;
    logic                            user_metadata_in_valid;
    logic [USER_META_DATA_WIDTH-1:0] user_metadata_out;
    logic                            user_metadata_out_valid;
    assign user_metadata_in       = '0;
    assign user_metadata_in_valid = 1'b0;

    // =========================================================================
    // DUT
    // =========================================================================
    vitisnetp4_forward DUT (
        .s_axis_aclk          ( s_axis_aclk          ),
        .s_axis_aresetn       ( s_axis_aresetn       ),
        .s_axi_aclk           ( s_axi_aclk           ),
        .s_axi_aresetn        ( s_axi_aresetn        ),
        .cam_mem_aclk         ( cam_mem_aclk         ),
        .cam_mem_aresetn      ( cam_mem_aresetn      ),
        .user_metadata_in     ( user_metadata_in     ),
        .user_metadata_in_valid ( user_metadata_in_valid ),
        .user_metadata_out    ( user_metadata_out    ),
        .user_metadata_out_valid ( user_metadata_out_valid ),
        .s_axi_awaddr         ( s_axi_awaddr         ),
        .s_axi_awvalid        ( s_axi_awvalid        ),
        .s_axi_awready        ( s_axi_awready        ),
        .s_axi_wdata          ( s_axi_wdata          ),
        .s_axi_wstrb          ( s_axi_wstrb          ),
        .s_axi_wvalid         ( s_axi_wvalid         ),
        .s_axi_wready         ( s_axi_wready         ),
        .s_axi_bresp          ( s_axi_bresp          ),
        .s_axi_bvalid         ( s_axi_bvalid         ),
        .s_axi_bready         ( s_axi_bready         ),
        .s_axi_araddr         ( s_axi_araddr         ),
        .s_axi_arvalid        ( s_axi_arvalid        ),
        .s_axi_arready        ( s_axi_arready        ),
        .s_axi_rdata          ( s_axi_rdata          ),
        .s_axi_rresp          ( s_axi_rresp          ),
        .s_axi_rvalid         ( s_axi_rvalid         ),
        .s_axi_rready         ( s_axi_rready         ),
        .s_axis_tdata         ( s_axis_tdata         ),
        .s_axis_tkeep         ( s_axis_tkeep         ),
        .s_axis_tvalid        ( s_axis_tvalid        ),
        .s_axis_tlast         ( s_axis_tlast         ),
        .s_axis_tready        ( s_axis_tready        ),
        .m_axis_tdata         ( m_axis_tdata         ),
        .m_axis_tkeep         ( m_axis_tkeep         ),
        .m_axis_tvalid        ( m_axis_tvalid        ),
        .m_axis_tlast         ( m_axis_tlast         ),
        .m_axis_tready        ( m_axis_tready        )
    );

    // =========================================================================
    // VitisNetP4 agent
    // =========================================================================
    xilinx_vitisnetp4_agent agent;

    // Capture %m at module scope — $sformatf("%m") inside build() would expand
    // to the SVUnit runner's path, not this module's path.
    string hier_path;
    initial hier_path = $sformatf("%m");

    // =========================================================================
    // AXI-L DPI-C task exports
    // Required by the VitisNetP4 DPI driver to perform register accesses.
    // =========================================================================
    export "DPI-C" task axi_lite_wr;
    task axi_lite_wr(input int address, input int data);
        @(posedge s_axi_aclk);
        fork
            begin
                s_axi_awvalid <= 1'b1;
                s_axi_awaddr  <= address;
                do @(posedge s_axi_aclk); while (!s_axi_awready);
                s_axi_awvalid <= 1'b0;
                s_axi_awaddr  <= 'x;
            end
            begin
                s_axi_wvalid <= 1'b1;
                s_axi_wstrb  <= '1;
                s_axi_wdata  <= data;
                do @(posedge s_axi_aclk); while (!s_axi_wready);
                s_axi_wvalid <= 1'b0;
                s_axi_wstrb  <= 'x;
                s_axi_wdata  <= 'x;
            end
        join
        s_axi_bready <= 1'b1;
        do @(posedge s_axi_aclk); while (!s_axi_bvalid);
        s_axi_bready <= 1'b0;
        `FAIL_IF_LOG(s_axi_bresp != 2'b00, "Bad AXI-L write response");
    endtask

    export "DPI-C" task axi_lite_rd;
    task axi_lite_rd(input int address, inout int data);
        @(posedge s_axi_aclk);
        s_axi_arvalid <= 1'b1;
        s_axi_araddr  <= address;
        do @(posedge s_axi_aclk); while (!s_axi_arready);
        s_axi_arvalid <= 1'b0;
        s_axi_araddr  <= 'x;
        s_axi_rready  <= 1'b1;
        do @(posedge s_axi_aclk); while (!s_axi_rvalid);
        s_axi_rready  <= 1'b0;
        data = s_axi_rdata;
        `FAIL_IF_LOG(s_axi_rresp != 2'b00, "Bad AXI-L read response");
    endtask

    // =========================================================================
    // CLI command file (stem — parse_cli_commands appends .txt)
    // =========================================================================
    string cli_commands_file;
    initial begin
        if (!$value$plusargs("CLI_COMMANDS_FILE=%s", cli_commands_file))
            cli_commands_file = "";
    end

    // =========================================================================
    // Build / setup / teardown
    // =========================================================================
    function void build();
        svunit_ut = new(name);
        agent = new("vitisnetp4_agent", hier_path, XilVitisNetP4Config);
    endfunction

    task setup();
        svunit_ut.setup();
        s_axis_tvalid <= 1'b0;
        s_axis_tlast  <= 1'b0;
        s_axis_tkeep  <= '0;
        s_axis_tdata  <= '0;
        m_axis_tready <= 1'b1;
        s_axi_awvalid <= 1'b0;
        s_axi_wvalid  <= 1'b0;
        s_axi_bready  <= 1'b0;
        s_axi_arvalid <= 1'b0;
        s_axi_rready  <= 1'b0;
        reset();
        agent.init();
    endtask

    task teardown();
        svunit_ut.teardown();
        agent.destroy();
    endtask

    // =========================================================================
    // Tests
    // =========================================================================
    `SVUNIT_TESTS_BEGIN

        // Verify the DUT resets cleanly.
        `SVTEST(hard_reset)
            reset();
        `SVTEST_END

        // Verify reset_tables completes without error.
        `SVTEST(reset_tables)
            agent.reset_tables();
        `SVTEST_END

        // Program forwardIPv4 and forwardIPv6 entries from the CLI command file.
        `SVTEST(table_init)
            agent.table_init_from_file(cli_commands_file);
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule : vitisnetp4_forward_unit_test
