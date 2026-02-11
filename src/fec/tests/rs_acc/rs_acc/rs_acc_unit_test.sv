`include "svunit_defines.svh"

// (Failsafe) timeout
`define SVUNIT_TIMEOUT 500us

module rs_acc_unit_test;

    import svunit_pkg::svunit_testcase;
    import tb_pkg::*;
    import fec_pkg::*;

    string name = $sformatf("rs_acc_ut");

    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int DATA_WID     = 512;
    localparam int SYM_PER_COL  = 1024;

    //===================================
    // Derived parameters
    //===================================
    localparam int PARITY_WID   = DATA_WID * RS_2T/RS_K;
    localparam int DATA_SYM_WID = DATA_WID / SYM_SIZE;
    localparam int SYM_PER_BLK  = SYM_PER_COL * RS_K;
    localparam int CLKS_PER_COL = SYM_PER_COL / DATA_SYM_WID;  // CLKS_PER_COL >= 4 (PIPE_STAGES).

    //===================================
    // Typedefs
    //===================================
    typedef logic [DATA_WID/SYM_SIZE-1:0]  [SYM_SIZE-1:0] DATA_T;
    typedef logic [PARITY_WID/SYM_SIZE-1:0][SYM_SIZE-1:0] PARITY_T;

    //===================================
    // DUT
    //===================================
    logic clk;
    logic srst;

    DATA_T  data_in;
    logic   data_in_valid;
    logic   data_in_ready;

    DATA_T  parity_out;
    logic   parity_out_valid;
    logic   parity_out_ready;
   
    rs_acc #(.DATA_WID(DATA_WID), .SYM_PER_COL(SYM_PER_COL)) DUT (.*);


    DATA_T  cw_to_col_data_in;
    logic   cw_to_col_valid;
    logic   cw_to_col_ready;

    fec_blk_transpose #(
        .DATA_WID       (DATA_WID),
        .NUM_COL        (RS_K),
        .SYM_PER_COL    (SYM_PER_COL),
        .MODE           (CW_TO_COL)
    ) fec_cw_to_col_inst (
        .clk            (clk),
        .srst           (srst),
        .data_in        (cw_to_col_data_in),
        .data_in_valid  (cw_to_col_valid),
        .data_in_ready  (cw_to_col_ready),
        .data_out       (data_in),
        .data_out_valid (data_in_valid),
        .data_out_ready (data_in_ready)
    );


    DATA_T  col_to_cw_data_out;
    logic   col_to_cw_valid;
    logic   col_to_cw_ready;

    fec_blk_transpose #(
        .DATA_WID       (DATA_WID),
        .NUM_COL        (RS_2T),
        .SYM_PER_COL    (SYM_PER_COL),
        .MODE           (COL_TO_CW)
    ) fec_col_to_cw_inst (
        .clk            (clk),
        .srst           (srst),
        .data_in        (parity_out),
        .data_in_valid  (parity_out_valid),
        .data_in_ready  (parity_out_ready),
        .data_out       (col_to_cw_data_out),
        .data_out_valid (col_to_cw_valid),
        .data_out_ready (col_to_cw_ready)
    );

    //===================================
    // Testbench
    //===================================
    rs_encode_tb_env #(1, DATA_T, PARITY_T) env;  // NUM_THREADS=1

    bus_intf #(DATA_WID)   wr_if (.clk);
    bus_intf #(DATA_WID)  _rd_if (.clk);
    bus_intf #(PARITY_WID) rd_if (.clk);

    // Assign data interfaces
    assign cw_to_col_valid   = wr_if.valid;
    assign cw_to_col_data_in = wr_if.data;
    assign wr_if.ready       = cw_to_col_ready;

    assign col_to_cw_ready   = _rd_if.ready;
    assign _rd_if.data       = col_to_cw_data_out;
    assign _rd_if.valid      = col_to_cw_valid;

    bus_width_converter #(.BIGENDIAN(0)) bus_width_converter_inst (
        .srst (srst),
        .from_tx (_rd_if),
        .to_rx (rd_if)
    );

    std_reset_intf reset_if (.clk);

    // Assign reset interface
    assign srst = reset_if.reset;

    initial reset_if.ready = 1'b0;
    always @(posedge clk) reset_if.ready <= ~srst;

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

    std_verif_pkg::raw_transaction#(DATA_T) transaction_in;

    DATA_T transaction_in_data[128];

    initial
        for (int i=0; i<128; i++)
            for (int j=0; j<DATA_WID/(RS_K*SYM_SIZE); j++)
                for (int k=0; k<RS_K; k++) transaction_in_data[i][j*RS_K+k] = k+(i/16);

    bit rx_done=0;

    string msg;

    `SVUNIT_TESTS_BEGIN

        `SVTEST(reset)
        `SVTEST_END

        `SVTEST(basic_sanity)
            int N=1024;

            for (int i=0; i<N; i++) begin
                // Send transaction
                for (int j=0; j<DATA_WID/SYM_SIZE; j++) transaction_in_data[0][j] = $urandom;

//                transaction_in = new("transaction_in", transaction_in_data[i%128]);
                transaction_in = new("transaction_in", transaction_in_data[0]);
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

endmodule : rs_acc_unit_test
