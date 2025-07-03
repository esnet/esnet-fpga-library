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
    typedef logic [AXIS_DATA_BYTE_WID-1:0]      axis_tkeep_t;
    typedef logic [AXIS_DATA_BYTE_WID-1:0][7:0] axis_tdata_t;

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

    logic [S_AXI_ADDR_WIDTH-1:0] s_axi_araddr;
    logic                        s_axi_arready;
    logic                        s_axi_arvalid;
    logic [S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr;
    logic                        s_axi_awready;
    logic                        s_axi_awvalid;
    logic                        s_axi_bready;
    logic [1:0]                  s_axi_bresp;
    logic                        s_axi_bvalid;
    logic [S_AXI_DATA_WIDTH-1:0] s_axi_rdata;
    logic                        s_axi_rready;
    logic [1:0]                  s_axi_rresp;
    logic                        s_axi_rvalid;
    logic [S_AXI_DATA_WIDTH-1:0] s_axi_wdata;
    logic                        s_axi_wready;
    logic [3:0]                  s_axi_wstrb;
    logic                        s_axi_wvalid;

    vitis_net_p4_0 DUT (.*);

    // Extern models
    extern_model  #(4, bit[2:0], bit, 1'b1) i_extern_model__counter (
        .clk       ( s_axis_aclk ),
        .srst      ( !s_axis_aresetn ),
        .valid_in  ( user_extern_out_valid.counter ),
        .data_in   ( user_extern_out.counter ),
        .valid_out ( user_extern_in_valid.counter ),
        .data_out  ( user_extern_in.counter )
    );

    //===================================
    // Testbench
    //===================================
    logic s_axis_sop;

    // Class managing VitisNetP4 DPI-C driver functions
    driver_pkg::driver vitisnetp4_drv;

    //===================================
    // Clocks
    //===================================
    initial s_axis_aclk = 0;
    always #1563ps s_axis_aclk = !s_axis_aclk;

    assign cam_mem_aclk = s_axis_aclk;

    initial s_axi_aclk = 0;
    always #5ns s_axi_aclk = !s_axi_aclk;

    //===================================
    // Input packet
    //===================================
    bit [0:13][7:0] eth = {
        // MAC
        48'h4574687B7E7E,
        48'h7E7E7E7E7E7D,
        // Ethertype
        16'h8100
    };

    bit [0:3][7:0] vlan_0 = {
        16'h564C,
        // Ethertype (IPv4)
        16'h0800
    };

    bit [0:19][7:0] ipv4 = {
        4'h4, // Version
        4'h5, // IHL
        8'h00, // DSCP/ECN
        16'h006e, // Total length
        16'h4950, // ID
        16'h0000, // Flags / Fragment offset
        8'h00, // TTL
        8'h06, // Protocol (TCP)
        16'h7634, // Checksum
        32'h7B7E7E7E, // SRC address,
        32'h7E7E7E7D  // DST address
    };

    bit [0:19][7:0] tcp = {
        16'h5443, // SRC port
        16'h507B, // DST port,
        32'h7E7E7E7E, // SEQ
        32'h7E7E7E7E, // ACK
        4'h5, // Header length
        4'h0, // RSVD
        8'h7E, // Flags
        16'h7E7E, // Window size
        16'h7E7E, // Checksum
        16'h7E7D  // Urgent pointer
    };

    bit [0:117][7:0] ipv4_tcp_pkt = {
        eth,
        vlan_0,
        ipv4,
        tcp,
        40'h50796C647B,
        {54{8'h7E}},
        8'h7D
    };

    //===================================
    // Execute sim
    //===================================
    initial begin
        idle();
        s_axis_aresetn = 1'b0;
        s_axi_aresetn = 1'b0;
        #100ns;
        $display($sformatf("[%0t] Deassert reset...", $time));
        s_axis_aresetn = 1'b1;
        s_axi_aresetn = 1'b1;
        #100ns;
        $display($sformatf("[%0t] Initialize driver...", $time));
        vitisnetp4_drv = new($sformatf("%m"));
        vitisnetp4_drv.init();
        $display($sformatf("[%0t] Writing table rules...", $time));
        add_rules();
        fork
            begin
                fork
                    send_packet({>>byte{ipv4_tcp_pkt}});
                    receive_packet();
                join
            end
            begin
                #1us;
                $display($sformatf("[%0t] Timeout.", $time));
            end
        join_any
        disable fork;
        #100ns;
        $display($sformatf("[%0t] Done.", $time));
        vitisnetp4_drv.cleanup();
        $finish;
    end
    assign cam_mem_aresetn = s_axis_aresetn;

    task s_axis_idle();
        s_axis_tvalid <= 1'b0;
        s_axis_tlast <= 1'b0;
        s_axis_tkeep <= '0;
        s_axis_tdata <= '0;
    endtask

    task m_axis_idle();
        m_axis_tready <= 1'b0;
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
        m_axis_idle();
        s_axi_idle();
    endtask

    task send_packet(input byte pkt[]);
        automatic byte __pkt[$] = pkt;
        automatic int size = __pkt.size();
        automatic int byte_idx;
        $display($sformatf("[%0t] Sent packet:",$time));
        $display(string_pkg::byte_array_to_string(pkt));

        @(posedge s_axis_aclk);
        while (__pkt.size() > 0) begin
            byte_idx = 0;
            s_axis_tvalid <= 1'b1;
            while (byte_idx < AXIS_DATA_BYTE_WID) begin
                if (__pkt.size() > 0) begin
                    s_axis_tdata[byte_idx] <= __pkt.pop_front();
                    s_axis_tkeep[byte_idx] <= 1'b1;
                end else begin
                    s_axis_tdata[byte_idx] <= '0;
                    s_axis_tkeep[byte_idx] <= 1'b0;
                end
                byte_idx++;
            end
            if (__pkt.size() > 0) s_axis_tlast <= 1'b0;
            else s_axis_tlast <= 1'b1;
            do @(posedge s_axis_aclk); while (!s_axis_tready);
        end
        s_axis_tvalid <= 1'b0;
        s_axis_tlast <= 'x;
        s_axis_tkeep <= 'x;
        s_axis_tdata <= 'x;
    endtask

    task receive_packet();
        automatic byte __pkt[$];
        automatic bit eop = 0;
        automatic int byte_idx = 0;

        @(posedge s_axis_aclk);
        m_axis_tready <= 1'b1;
        while (!eop) begin
            do @(posedge s_axis_aclk); while (!m_axis_tvalid);
            while (byte_idx < AXIS_DATA_BYTE_WID) begin
                if (m_axis_tkeep[byte_idx]) __pkt.push_back(m_axis_tdata[byte_idx]);
                byte_idx++;
            end
            if (m_axis_tlast) eop = 1'b1;
            byte_idx = 0;
        end
        m_axis_tready <= 1'b0;
        $display($sformatf("[%0t] Received packet:",$time));
        $display(string_pkg::byte_array_to_string(__pkt));
    endtask

    // Export AXI-L accessors to VitisNetP4 shared library
    export "DPI-C" task axi_lite_wr;
    task axi_lite_wr(input int address, input int data);
        @(posedge s_axi_aclk);
        fork
            begin
                s_axi_awvalid <= 1'b1;
                s_axi_awaddr <= address;
                do @(posedge s_axi_aclk); while (!s_axi_awready);
                s_axi_awvalid <= 1'b0;
                s_axi_awaddr <= 'x;
            end
            begin
                s_axi_wvalid <= 1'b1;
                s_axi_wstrb <= '1;
                s_axi_wdata <= data;
                do @(posedge s_axi_aclk); while (!s_axi_wready);
                s_axi_wvalid <= 1'b0;
                s_axi_wstrb <= 'x;
                s_axi_wdata <= 'x;
            end
        join
        s_axi_bready <= 1'b1;
        do @(posedge s_axi_aclk); while (!s_axi_bvalid);
        s_axi_bready <= 1'b0;
        if (s_axi_bresp != 2'b00) $error("Bad AXI-L write");
    endtask

    export "DPI-C" task axi_lite_rd;
    task axi_lite_rd(input int address, inout int data);
        @(posedge s_axi_aclk);
        s_axi_arvalid <= 1'b1;
        s_axi_araddr <= address;
        do @(posedge s_axi_aclk); while (!s_axi_arready);
        s_axi_arvalid <= 1'b0;
        s_axi_araddr <= 'x;
        s_axi_rready <= 1'b1;
        do @(posedge s_axi_aclk); while (!s_axi_rvalid);
        s_axi_rready <= 1'b0;
        data = s_axi_rdata;
        if (s_axi_rresp != 2'b00) $error("Bad AXI-L read");
    endtask

    task add_rules();
    endtask

endmodule
