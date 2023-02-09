module test;

    //===================================
    // Imports
    //===================================
    import vitis_net_p4_0_pkg::*;

    //===================================
    // Parameters
    //===================================
    localparam int AXIS_DATA_BYTE_WID = 64;

    //===================================
    // Typedefs
    //===================================
    typedef logic [AXIS_DATA_BYTE_WID-1:0]   axis_tkeep_t;
    typedef logic [AXIS_DATA_BYTE_WID*8-1:0] axis_tdata_t;

    //===================================
    // DUT
    //===================================
    logic s_axis_aclk;
    logic s_axis_aresetn;
    logic cam_mem_aclk;
    logic cam_mem_aresetn;
    logic s_axi_aclk;
    logic s_axi_aresetn;

    USER_META_DATA_T user_metadata_in;
    bit              user_metadata_in_valid;
    USER_META_DATA_T user_metadata_out;
    bit              user_metadata_out_valid;

    axis_tdata_t     s_axis_tdata;
    axis_tkeep_t     s_axis_tkeep;
    bit              s_axis_tvalid;
    bit              s_axis_tlast;
    bit              s_axis_tready;

    axis_tdata_t     m_axis_tdata;
    axis_tkeep_t     m_axis_tkeep;
    logic            m_axis_tvalid;
    logic            m_axis_tlast;
    logic            m_axis_tready;

    USER_EXTERN_OUT_T   user_extern_out;
    USER_EXTERN_VALID_T user_extern_out_valid;
    USER_EXTERN_IN_T    user_extern_in;
    USER_EXTERN_VALID_T user_extern_in_valid;

    logic [13:0] s_axi_araddr;
    logic        s_axi_arready;
    logic        s_axi_arvalid;
    logic [13:0] s_axi_awaddr;
    logic        s_axi_awready;
    logic        s_axi_awvalid;
    logic        s_axi_bready;
    logic [1:0]  s_axi_bresp;
    logic        s_axi_bvalid;
    logic [31:0] s_axi_rdata;
    logic        s_axi_rready;
    logic [1:0]  s_axi_rresp;
    logic        s_axi_rvalid;
    logic [31:0] s_axi_wdata;
    logic        s_axi_wready;
    logic [3:0]  s_axi_wstrb;
    logic        s_axi_wvalid;

    vitis_net_p4_0 DUT (.*);

    //===================================
    // Testbench
    //===================================
    logic s_axis_sop;

    //===================================
    // Clocks
    //===================================
    initial s_axis_aclk = 0;
    always #1563ps s_axis_aclk = !s_axis_aclk;

    assign cam_mem_aclk = s_axis_aclk;

    initial s_axi_aclk = 0;
    always #5ns s_axi_aclk = !s_axi_aclk;

    //===================================
    // Resets
    //===================================
    initial begin
        idle();
        s_axis_aresetn = 1'b0;
        s_axi_aresetn = 1'b0;
        #100ns;
        $display("Deassert reset...");
        s_axis_aresetn = 1'b1;
        s_axi_aresetn = 1'b1;
        #100ns;
        send_packet();
        #100ns;
        send_packet();
        send_packet();
        #100ns;
        $display("Done.");
        $finish;
    end
    assign cam_mem_aresetn = s_axis_aresetn;

    // Flush AXI-S output interface
    assign m_axis_tready = 1'b1;

    task s_axis_idle();
        s_axis_tvalid <= 1'b0;
        s_axis_tlast <= 1'b0;
        s_axis_tkeep <= '0;
        s_axis_tdata <= '0;
    endtask

    initial s_axis_sop = 1'b1;
    always @(posedge s_axis_aclk) begin
        if (!s_axis_aresetn) s_axis_sop <= 1'b1;
        else if (s_axis_tvalid && s_axis_tready) begin
            if (s_axis_tlast) s_axis_sop <= 1'b1;
            else              s_axis_sop <= 1'b0;
        end
    end

    assign user_metadata_in_valid = s_axis_tvalid && s_axis_sop;
    assign user_metadata_in = '0;

    task s_axi_idle();
        s_axi_awvalid <= 1'b0;
        s_axi_arvalid <= 1'b0;
        s_axi_wvalid <= 1'b0;
        s_axi_bready <= 1'b0;
        s_axi_rready <= 1'b0;
        s_axi_awaddr <= 'x;
        s_axi_wdata <= 'x;
        s_axi_wstrb <= 'x;
    endtask

    task idle();
        s_axis_idle();
        s_axi_idle();
    endtask


    bit [7:0][0:63] header = {
        // MAC
        48'h000000000500,
        48'h000000000400,
        // Ethertype
        16'h8100,
        // VLAN
        16'h007e,
        16'h0800,
        // IPv4
        4'h4, // Version
        4'h5, // IHL
        8'h0, // DSCP/ECN
        16'h6c, // Total length
        16'h0001, // ID
        3'h0, // Flags
        13'h0, // Fragment offset
        8'h40, // TTL
        8'h06, // Protocol
        16'h523f, // Checksum
        32'h0A0F0A28, // SRC address,
        32'h0A0A0A0A, // DST address
        // TCP
        16'h1448, // SRC port
        16'hfde8, // DST port,
        32'h0, // SEQ
        32'h0, // ACK
        4'h5, // Header length
        4'h0, // RSVD
        8'h02, // Flags
        16'h2000, // Window size
        16'h04d1, // Checksum
        16'h0000, // Urgent pointer
        // Payload
        48'h616161616161
    };

    task send_packet();
        $display("Send packet");
        @(posedge s_axis_aclk);
        s_axis_tvalid <= 1'b1;
        s_axis_tkeep <= '1;
        s_axis_tlast <= 1'b0;
        s_axis_tdata <=  {<<8{header}};
        do @(posedge s_axis_aclk); while (!s_axis_tready);
        s_axis_tvalid <= 1'b1;
        s_axis_tkeep <= '1;
        s_axis_tlast <= 1'b1;
        s_axis_tdata <= '1;
        do @(posedge s_axis_aclk); while (!s_axis_tready);
        s_axis_idle();
    endtask

    // Export AXI-L accessors to VitisNetP4 shared library
    export "DPI-C" task axi_lite_wr;
    task axi_lite_wr(input int address, input int data);
        @(posedge s_axi_aclk);
    endtask

    export "DPI-C" task axi_lite_rd;
    task axi_lite_rd(input int address, inout int data);
        @(posedge s_axi_aclk);
        data = '0;
    endtask

    // Extern models
    extern_model  #(4, bit[2:0], bit, 1'b1) i_extern_model__counter (
        .clk       ( s_axis_aclk ),
        .srst      ( !s_axis_aresetn ),
        .valid_in  ( user_extern_out_valid.counter ),
        .data_in   ( user_extern_out.counter ),
        .valid_out ( user_extern_in_valid.counter ),
        .data_out  ( user_extern_in.counter )
    );

endmodule

module extern_model #(
    parameter int LATENCY = 4,
    parameter type DATA_IN_T = bit,
    parameter type DATA_OUT_T = bit,
    parameter DATA_OUT_T DATA_OUT = '0
)(
    input logic       clk,
    input logic       srst,
    input logic       valid_in,
    input DATA_IN_T   data_in,
    output logic      valid_out,
    output DATA_OUT_T data_out
);
    logic valid_p [LATENCY];

    initial valid_p = '{LATENCY{1'b0}};
    always @(posedge clk) begin
        if (srst) valid_p <= '{LATENCY{1'b0}};
        else begin
            for (int i = 1; i < LATENCY; i++) valid_p[i] <= valid_p[i-1];
            valid_p[0] <= valid_in;
        end
    end
    assign valid_out = valid_p[LATENCY-1];

    assign data_out = DATA_OUT;

endmodule : extern_model
