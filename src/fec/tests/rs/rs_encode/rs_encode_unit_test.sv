`include "svunit_defines.svh"

// (Failsafe) timeout
`define SVUNIT_TIMEOUT 500us

module rs_encode_unit_test;

    import svunit_pkg::svunit_testcase;
    import tb_pkg::*;
    import fec_pkg::*;

    string name = $sformatf("rs_encode_ut");

    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int DATA_IN_WID    = RS_K  * SYM_SIZE;
    localparam int PARITY_OUT_WID = RS_2T * SYM_SIZE;

    //===================================
    // Derived parameters
    //===================================

    //===================================
    // Typedefs
    //===================================
    typedef logic [RS_K -1:0][SYM_SIZE-1:0] DATA_IN_T;
    typedef logic [RS_2T-1:0][SYM_SIZE-1:0] PARITY_OUT_T;

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

    rs_encode DUT (.*);

    //===================================
    // Testbench
    //===================================
    rs_encode_tb_env #(1, DATA_IN_T, PARITY_OUT_T) env;  // NUM_THREADS=1

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
            int N=500;

            for (int i=0; i<N; i++) begin
                // Send transaction
                for (int j=0; j<RS_N; j++) transaction_in_data[j] = $urandom;
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

endmodule : rs_encode_unit_test
