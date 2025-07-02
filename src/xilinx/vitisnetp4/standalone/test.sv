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
        48'haaaaaaaaaaaa,
        48'haaaaaaaaaaaa,
        // Ethertype
        16'h8100
    };

    bit [0:3][7:0] vlan_0 = {
        16'hbbbb,
        // Ethertype (IPv4)
        16'h0800
    };

    bit [0:19][7:0] ipv4 = {
        4'h4, // Version
        4'hc, // IHL
        8'hcc, // DSCP/ECN
        16'h006e, // Total length
        16'hcccc, // ID
        16'hcccc, // Flags / Fragment offset
        8'hcc, // TTL
        8'h06, // Protocol (TCP)
        16'hcccc, // Checksum
        32'hcccccccc, // SRC address,
        32'hcccccccc  // DST address
    };

    bit [0:19][7:0] tcp = {
        16'hdddd, // SRC port
        16'hdddd, // DST port,
        32'hdddddddd, // SEQ
        32'hdddddddd, // ACK
        4'h5, // Header length
        4'hd, // RSVD
        8'hdd, // Flags
        16'hdddd, // Window size
        16'hdddd, // Checksum
        16'hdddd  // Urgent pointer
    };

    bit [0:1][0:63][7:0] ipv4_tcp_pkt = {
        eth,
        vlan_0,
        ipv4,
        tcp,
        {80{8'hee}}
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
        automatic int byte_idx = 0;
        $display($sformatf("[%0t] Sent packet:",$time));
        $display(string_pkg::byte_array_to_string(pkt));

        @(posedge s_axis_aclk);
        while (__pkt.size() > 0) begin
            s_axis_tdata[byte_idx] <= __pkt.pop_front();
            s_axis_tkeep[byte_idx] <= 1'b1;
            byte_idx++;
            if ((byte_idx == AXIS_DATA_BYTE_WID) || (__pkt.size() == 0)) begin
                if (__pkt.size() == 0) s_axis_tlast <= 1'b1;
                else s_axis_tlast <= 1'b0;
                s_axis_tvalid <= 1'b1;
                byte_idx = 0;
                do @(posedge s_axis_aclk); while (!s_axis_tready);
            end
        end
        s_axis_tvalid <= 1'b0;
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
    endtask

    export "DPI-C" task axi_lite_rd;
    task axi_lite_rd(input int address, inout int data);
        @(posedge s_axi_aclk);
        data = '0;
    endtask

endmodule
