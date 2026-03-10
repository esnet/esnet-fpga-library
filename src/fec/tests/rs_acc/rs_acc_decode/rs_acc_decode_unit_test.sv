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
    localparam int COL_LEN   = 512; //8192;

    localparam int CLKS_PER_BLK = (RS_N*COL_LEN)/(DATA_WID/SYM_SIZE);

    //===================================
    // Typedefs
    //===================================
    typedef logic [DATA_WID-1:0] DATA_T;

    //===================================
    // DUTs (rs_acc_encode -> rs_acc_err_inj -> rs_acc_decode)
    //===================================
    logic clk;
    logic srst;

    DATA_T data_in;
    logic  data_in_valid;
    logic  data_in_ready;

    DATA_T enc_out;
    logic  enc_out_valid;
    logic  enc_out_ready;

    rs_acc_encode #(.DATA_WID(DATA_WID), .COL_LEN(COL_LEN)) DUT_ENC (
        .clk            (clk),
        .srst           (srst),
        .data_in        (data_in),
        .data_in_valid  (data_in_valid),
        .data_in_ready  (data_in_ready),
        .data_out       (enc_out),
        .data_out_valid (enc_out_valid),
        .data_out_ready (enc_out_ready)
    );

    logic [$clog2(CLKS_PER_BLK)-1:0] index   = '0;
    logic [$clog2(NUM_H)-1:0]        err_loc = 5;

    always @(posedge clk) if (enc_out_valid && enc_out_ready) begin
        index   <= (index == CLKS_PER_BLK-1) ? '0 : index+1;
        err_loc <= (index == CLKS_PER_BLK-1) ? ($urandom % NUM_H) : err_loc;
    end

    DATA_T inj_out;
    logic  inj_out_valid;
    logic  inj_out_ready;

    rs_acc_err_inj #(.DATA_WID(DATA_WID), .COL_LEN(COL_LEN)) DUT_INJ (
        .clk            (clk),
        .srst           (srst),
        .data_in        (enc_out),
        .data_in_valid  (enc_out_valid),
        .data_in_ready  (enc_out_ready),
        .err_loc_vec    (RS_ERR_LOC_LUT[err_loc]),
        .data_out       (inj_out),
        .data_out_valid (inj_out_valid),
        .data_out_ready (inj_out_ready)
    );

    DATA_T data_out;
    logic  data_out_valid;
    logic  data_out_ready;

    rs_acc_decode #(.DATA_WID(DATA_WID), .COL_LEN(COL_LEN)) DUT_DEC (
        .clk            (clk),
        .srst           (srst),
        .data_in        (inj_out),
        .data_in_valid  (inj_out_valid),
        .data_in_ready  (inj_out_ready),
        .err_loc        (err_loc),
        .data_out       (data_out),
        .data_out_valid (data_out_valid),
        .data_out_ready (data_out_ready)
    );

    //===================================
    // Testbench
    //===================================
    rs_decode_tb_env #(1, DATA_T) env;  // NUM_THREADS=1

    bus_intf #(DATA_WID) wr_if (.clk);
    bus_intf #(DATA_WID) rd_if (.clk);

    std_reset_intf reset_if (.clk);

    // Assign reset interface
    assign srst = reset_if.reset;

    initial reset_if.ready = 1'b0;
    always @(posedge clk) reset_if.ready <= ~srst;

    // Assign data interfaces
    assign data_in_valid  = wr_if.valid;
    assign data_in        = wr_if.data;
    assign wr_if.ready    = data_in_ready;

    assign data_out_ready = rd_if.ready;
    assign rd_if.data     = data_out;
    assign rd_if.valid    = data_out_valid;

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
            int N=1024;

            for (int i=0; i<N; i++) begin
                // Send transaction
                for (int j=0; j<DATA_WID; j++) transaction_in_data[j] = $urandom;
                transaction_in = new("transaction_in", transaction_in_data);
                env.inbox.put(transaction_in);
            end

            fork
                #40us if (!rx_done) `INFO("TIMEOUT! waiting for rx packets...");

                while (!rx_done) #100ns if (env.scoreboard.exp_pending()==0) rx_done=1;
            join_any
	      
            #100ns;
            `FAIL_IF_LOG( env.scoreboard.report(msg) > 0, msg );
            `FAIL_UNLESS_EQUAL( env.scoreboard.got_matched(), N );
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule : rs_acc_decode_unit_test
