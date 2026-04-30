`include "svunit_defines.svh"

// (Failsafe) timeout
`define SVUNIT_TIMEOUT 500us

module rs_acc_decode_unit_test;

    import svunit_pkg::svunit_testcase;
    import tb_pkg::*;
    import fec_pkg::*;

    string name = $sformatf("rs_acc_decode_ut");

    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int DATA_WID  = 512;
    localparam int COL_LEN   = 4096;

    localparam int CLKS_PER_BLK    = RS_K * COL_LEN * SYM_SIZE / DATA_WID;
    localparam int CLKS_PER_CW_BLK = RS_N * COL_LEN * SYM_SIZE / DATA_WID;

    //===================================
    // Typedefs
    //===================================
    typedef logic [DATA_WID-1:0] DATA_T;

    typedef logic [$clog2(CLKS_PER_BLK)-1:0] INDEX_T;

    typedef logic [$clog2(CLKS_PER_CW_BLK)-1:0] CW_INDEX_T;

    //===================================
    // DUTs (rs_acc_encode -> rs_acc_err_inj -> rs_acc_decode)
    //===================================
    logic clk;
    logic srst;
    logic [31:0] fec_evt_size;
    logic [31:0] last_pkt_size;

    rs_acc_intf #(.DATA_WID(DATA_WID), .COL_LEN(COL_LEN)) data_in  (.clk(clk));
    rs_acc_intf #(.DATA_WID(DATA_WID), .COL_LEN(COL_LEN)) frm_out  (.clk(clk));
    rs_acc_intf #(.DATA_WID(DATA_WID), .COL_LEN(COL_LEN)) enc_out  (.clk(clk));
    rs_acc_intf #(.DATA_WID(DATA_WID), .COL_LEN(COL_LEN)) inj_out  (.clk(clk));
    rs_acc_intf #(.DATA_WID(DATA_WID), .COL_LEN(COL_LEN)) data_out (.clk(clk));

    rs_acc_framer #(.DATA_WID(DATA_WID), .COL_LEN(COL_LEN)) DUT_FRM (
        .clk               (clk),
        .srst              (srst),
        .fec_evt_size      (fec_evt_size),
        .data_in           (data_in),
        .data_out          (frm_out)
    );

    rs_acc_encode #(.DATA_WID(DATA_WID), .COL_LEN(COL_LEN)) DUT_ENC (
        .clk               (clk),
        .srst              (srst),
        .data_in           (frm_out),
        .data_out          (enc_out)
    );

    CW_INDEX_T index = '0;

    logic [$clog2(NUM_H)-1:0] err_loc = 0;

    always @(posedge clk) if (enc_out.valid && enc_out.ready) begin
        index   <= (index == CLKS_PER_CW_BLK-1) ? '0 : index+1;
        err_loc <= (index == CLKS_PER_CW_BLK-1) ? ($urandom % NUM_H) : err_loc;
    end

    rs_acc_err_inj #(.DATA_WID(DATA_WID), .COL_LEN(COL_LEN)) DUT_INJ (
        .clk               (clk),
        .srst              (srst),
        .err_loc_vec       (RS_ERR_LOC_LUT[err_loc]),
        .data_in           (enc_out),
        .data_out          (inj_out)
    );

    rs_acc_decode #(.DATA_WID(DATA_WID), .COL_LEN(COL_LEN)) DUT_DEC (
        .clk               (clk),
        .srst              (srst),
        .err_loc           (err_loc),
        .data_in           (inj_out),
        .data_out          (data_out)
    );

    //===================================
    // Testbench
    //===================================
    int N;  // N = number of packets

    rs_decode_tb_env #(1, DATA_T) env;  // NUM_THREADS=1

    bus_intf #(DATA_WID) wr_if (.clk);
    bus_intf #(DATA_WID) rd_if (.clk);

    std_reset_intf reset_if (.clk);

    // Assign reset interface
    assign srst = reset_if.reset;

    initial reset_if.ready = 1'b0;
    always @(posedge clk) reset_if.ready <= ~srst;

    // Assign data interfaces
    int pkt_cnt=0;
    always @(posedge clk) if (data_in.valid && data_in.ready) pkt_cnt++;

    assign data_in.data     = wr_if.data;
    assign data_in.valid    = wr_if.valid;
    assign wr_if.ready      = data_in.ready;

    assign rd_if.data       = data_out.data;
    assign rd_if.valid      = data_out.valid;
    assign data_out.ready   = rd_if.ready;

    // Assign clock (100MHz)
    `SVUNIT_CLK_GEN(clk, 5ns);

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        // Create testbench environment
        env = new("rs_decode_tb_env", reset_if, wr_if, rd_if);
        env.build();
        env.set_debug_level(1);

    endfunction

    //===================================
    // Setup for running the Unit Tests
    //===================================
    int max_stall = $urandom % 4;  // stall range max is randomly chosen (0-3).
    task setup();
        svunit_ut.setup();
        env.run();

        env.monitor.set_max_stall(.max_stall(max_stall));
        env.monitor.enable_stalls(.stall_cycles(0));  // 0 is random within stall range (default is 0-4).
        #50ns;

    endtask

    //===================================
    // Here we deconstruct anything we
    // need after running the Unit Tests
    //===================================
    task teardown();
        svunit_ut.teardown();

    endtask

    //===================================
    // All tests are defined between the
    // SVUNIT_TESTS_BEGIN/END macros
    //
    // Each individual test must be
    // defined between `SVTEST(_NAME_)
    // `SVTEST_END
    //
    // i.e.
    //   `SVTEST(mytest)
    //     <test code>
    //   `SVTEST_END
    //===================================

    std_verif_pkg::raw_transaction#(DATA_T) transaction_in;

    DATA_T transaction_in_data;
    initial begin
        transaction_in_data[0]=1;
        transaction_in_data[1]=2;
        transaction_in_data[2]=3;
        transaction_in_data[3]=4;
        transaction_in_data[4]=5;
        transaction_in_data[5]=6;
        transaction_in_data[6]=7;
        transaction_in_data[7]=8;
    end

    bit rx_done=0;
    string msg;


    `SVUNIT_TESTS_BEGIN

        `SVTEST(reset)
        `SVTEST_END

        `SVTEST(basic_sanity)
            N = $urandom_range(1024,1);
            last_pkt_size = $urandom_range(DATA_WID/8,1);
            fec_evt_size = N * DATA_WID/8 + last_pkt_size;

            // send first N packets.
            for (int i=0; i<N; i++) begin
                // Send transaction
                for (int j=0; j<DATA_WID; j++) transaction_in_data[j] = $urandom;
                transaction_in = new("transaction_in", transaction_in_data);
                env.inbox.put(transaction_in);
            end

            // send last packet.
            for (int j=0; j<DATA_WID; j++) transaction_in_data[j] = (j < last_pkt_size*8) ? $urandom : 0;
            transaction_in = new("transaction_in", transaction_in_data);
            env.inbox.put(transaction_in);

            fork
                #40us if (!rx_done) `INFO("TIMEOUT! waiting for rx packets...");

                while (!rx_done) #100ns if (env.scoreboard.exp_pending()==0) rx_done=1;
            join_any
	      
            #100ns;
            `FAIL_IF_LOG( env.scoreboard.report(msg) > 0, msg );
            `FAIL_UNLESS_EQUAL( env.scoreboard.got_matched(), N+1 );
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule : rs_acc_decode_unit_test
