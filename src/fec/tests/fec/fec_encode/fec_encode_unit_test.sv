`include "svunit_defines.svh"

// (Failsafe) timeout
`define SVUNIT_TIMEOUT 500us

module fec_encode_unit_test;

    import svunit_pkg::svunit_testcase;
    import tb_pkg::*;
    import fec_pkg::*;

    string name = $sformatf("fec_encode_ut");

    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int DATA_IN_WID = 512;
    localparam int NUM_THREADS = 2;

    //===================================
    // Derived parameters
    //===================================
    localparam int PARITY_OUT_WID = DATA_IN_WID * RS_2T / RS_K;
    localparam int NUM_CW         = DATA_IN_WID / (RS_K * NUM_THREADS * SYM_SIZE);

    //===================================
    // Typedefs
    //===================================
    typedef logic [NUM_CW*RS_K -1:0][NUM_THREADS*SYM_SIZE-1:0] DATA_IN_T;
    typedef logic [NUM_CW*RS_2T-1:0][NUM_THREADS*SYM_SIZE-1:0] PARITY_OUT_T;

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;

    DATA_IN_T  data_in;
    logic      data_in_valid;
    logic      data_in_ready;

    DATA_IN_T  data_out;
    PARITY_OUT_T parity_out;
    logic      data_out_valid;
    logic      data_out_ready;

    fec_encode #(.DATA_WID(DATA_IN_WID), .NUM_THREADS(NUM_THREADS)) DUT (.*);

    //===================================
    // Testbench
    //===================================
    rs_encode_tb_env #(NUM_THREADS, DATA_IN_T, PARITY_OUT_T) env;

    bus_intf #(DATA_IN_WID)    wr_if (.clk);
    bus_intf #(PARITY_OUT_WID) rd_if (.clk);

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
    assign rd_if.data     = parity_out;
    assign rd_if.valid    = data_out_valid;

    // Assign clock (100MHz)
    `SVUNIT_CLK_GEN(clk, 5ns);

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);

        // Create testbench environment
        env = new("rs_encode_tb_env", reset_if, wr_if, rd_if);
        env.build();
        env.set_debug_level(1);

    endfunction

    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();
        env.run();

        env.monitor.enable_stalls(.stall_cycles(0));  // 0 is random within default range (0-4).
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

    std_verif_pkg::raw_transaction#(DATA_IN_T) transaction_in;

    DATA_IN_T transaction_in_data;

    initial begin
        transaction_in_data='0;

        transaction_in_data[0] =8'h1;
        transaction_in_data[1] =8'h2;
        transaction_in_data[2] =8'h3;
        transaction_in_data[3] =8'h4;
        transaction_in_data[4] =8'h5;
        transaction_in_data[5] =8'h6;
        transaction_in_data[6] =8'h7;
        transaction_in_data[7] =8'h8;
        transaction_in_data[8] =8'h10;
        transaction_in_data[9] =8'h20;
        transaction_in_data[10]=8'h30;
        transaction_in_data[11]=8'h40;
        transaction_in_data[12]=8'h50;
        transaction_in_data[13]=8'h60;
        transaction_in_data[14]=8'h70;
        transaction_in_data[15]=8'h80;
    end

    bit rx_done=0;

    string msg;


    `SVUNIT_TESTS_BEGIN

        `SVTEST(reset)
        `SVTEST_END

        `SVTEST(basic_sanity)
            int N=500;

            for (int i=0; i<N; i++) begin
                // Send transaction
                for (int j=0; j<NUM_CW; j++)
                    for (int k=0; k<RS_K; k++) transaction_in_data[j*RS_K+k] = $urandom;

                transaction_in = new("transaction_in", transaction_in_data);
                env.inbox.put(transaction_in);
            end

            fork
                #20us if (!rx_done) `INFO("TIMEOUT! waiting for rx packets...");

                while (!rx_done) #100ns if (env.scoreboard.exp_pending()==0) rx_done=1;
            join_any
	      
            #100ns;
            `FAIL_IF_LOG( env.scoreboard.report(msg) > 0, msg );
            `FAIL_UNLESS_EQUAL( env.scoreboard.got_matched(), N );
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule : fec_encode_unit_test
