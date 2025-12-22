`include "svunit_defines.svh"

// (Failsafe) timeout
`define SVUNIT_TIMEOUT 500us

module fec_decode_unit_test;

    import svunit_pkg::svunit_testcase;
    import tb_pkg::*;
    import fec_pkg::*;

    string name = $sformatf("fec_decode_ut");

    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
    localparam int DATA_IN_WID  = 512;
    localparam int NUM_THREADS  = 2;
    localparam int NUM_CW       = DATA_IN_WID / (RS_K * NUM_THREADS * SYM_SIZE);

    //===================================
    // Typedefs
    //===================================
    typedef logic [NUM_CW*RS_K -1:0][NUM_THREADS*SYM_SIZE-1:0] DATA_IN_T;
    typedef logic [NUM_CW*RS_2T-1:0][NUM_THREADS*SYM_SIZE-1:0] PARITY_OUT_T;

    //===================================
    // DUTs (fec_encode -> inject_errors -> fec_decode)
    //===================================
    logic clk;
    logic srst;

    DATA_IN_T     data_in;
    logic         data_in_valid;
    logic         data_in_ready;

    DATA_IN_T     data_out;
    PARITY_OUT_T  parity_out;
    logic         data_out_valid;
    logic         data_out_ready;

    fec_encode DUT0 (.*);


    DATA_IN_T dec_data_in;
    logic [$clog2(NUM_H)-1:0] dec_err_loc;

    always @(negedge clk) if (data_out_valid)
        inject_errors (
            .data_in   (data_out),
            .parity_in (parity_out),
            .data_out  (dec_data_in),
            .err_loc   (dec_err_loc) );


    DATA_IN_T  dec_data_out;
    logic      dec_data_out_valid;
    logic      dec_data_out_ready;

    fec_decode DUT1 (
        .clk            (clk),
        .srst           (srst),

        .data_in        (dec_data_in),
        .err_loc        (dec_err_loc),
        .data_in_valid  (data_out_valid),
        .data_in_ready  (data_out_ready),

        .data_out       (dec_data_out),
        .data_out_valid (dec_data_out_valid),
        .data_out_ready (dec_data_out_ready)
    );


    function void inject_errors (
        input  DATA_IN_T     data_in,
        input  PARITY_OUT_T  parity_in,

        output DATA_IN_T     data_out,
        output [$clog2(NUM_H)-1:0] err_loc
    );

        logic [NUM_CW-1:0][RS_N-1:0][NUM_THREADS*SYM_SIZE-1:0] _data_out;
        int num_errors;

        err_loc = $urandom % NUM_H;

        // restructure input data.  collect rs codewords.
        for (int i=0; i<NUM_CW; i++)
            for (int j=0; j<RS_N; j++)
                if (j < RS_K) _data_out[i][j] =   data_in[i*RS_K+j];
                else          _data_out[i][j] = parity_in[i*RS_2T+j-RS_K];

        // delete error locations and compress output data.
        for (int i=0; i<NUM_CW; i++) begin
            num_errors=0;
            for (int j=0; j<RS_N; j++) begin
                if (RS_ERR_LOC_LUT[err_loc][j] == 1'b0) _data_out[i][j-num_errors] = _data_out[i][j];
                else num_errors++;
            end
        end

        // output data assignments.
        for (int i=0; i<NUM_CW; i++)
            for (int j=0; j<RS_K; j++)
                data_out[i*RS_K+j] = _data_out[i][j];

        //$display ("err_loc = %d, %h, data_out = %h", err_loc, RS_ERR_LOC_LUT[err_loc], data_out);

    endfunction // inject_errors


    //===================================
    // Testbench
    //===================================
    rs_decode_tb_env #(NUM_THREADS, DATA_IN_T) env;

    bus_intf #(DATA_IN_WID) wr_if (.clk);
    bus_intf #(DATA_IN_WID) rd_if (.clk);

    std_reset_intf reset_if (.clk);

    // Assign reset interface
    assign srst = reset_if.reset;

    initial reset_if.ready = 1'b0;
    always @(posedge clk) reset_if.ready <= ~srst;

    // Assign data interfaces
    assign data_in_valid  = wr_if.valid;
    assign data_in        = wr_if.data;
    assign wr_if.ready    = data_in_ready;

    assign dec_data_out_ready = rd_if.ready;
    assign rd_if.data         = dec_data_out;
    assign rd_if.valid        = dec_data_out_valid;

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
                for (int j=0; j<NUM_CW; j++)
                    for (int k=0; k<RS_K; k++) transaction_in_data[j*RS_K+k] = $urandom;

                transaction_in = new("transaction_in", transaction_in_data);
                env.inbox.put(transaction_in);
            end

            fork
                #10us if (!rx_done) `INFO("TIMEOUT! waiting for rx packets...");

                while (!rx_done) #100ns if (env.scoreboard.exp_pending()==0) rx_done=1;
            join_any
	      
            #100ns;
            `FAIL_IF_LOG( env.scoreboard.report(msg) > 0, msg );
            `FAIL_UNLESS_EQUAL( env.scoreboard.got_matched(), N );
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule : fec_decode_unit_test
