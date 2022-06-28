`include "svunit_defines.svh"

`define SVUNIT_TIMEOUT 500us

module axi4s_split_join_unit_test
#(
    parameter int  DATA_BYTE_WID = 16
 );
    import svunit_pkg::svunit_testcase;
    import packet_verif_pkg::*;
    import axi4s_pkg::*;
    import axi4s_verif_pkg::*;
    import pcap_pkg::*;

    string name = $sformatf("axi4s_split_join_datawidth_%0d_ut", DATA_BYTE_WID);
    svunit_testcase svunit_ut;

    //===================================
    // Parameters
    //===================================
 
    localparam type TID_T = bit;
    localparam type TDEST_T = bit;
    localparam type TUSER_T = bit;

    localparam BIGENDIAN = 1;

    int  hdr_slice_length;

    // drop header (used on packets that will be dropped by header processing logic).
    byte drop_hdr [];
    byte prefix [];
    int  hdr_trunc_length;

    typedef axi4s_transaction#(TID_T,TDEST_T,TUSER_T) AXI4S_TRANSACTION_T;

    //===================================
    // DUT and header processor
    //===================================
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID)) axi4s_in  ();
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID)) axi4s_out ();

    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TUSER_MODE(BUFFER_CONTEXT), .TUSER_T(tuser_buffer_context_mode_t)) axi4s_hdr_in();
    axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TUSER_MODE(BUFFER_CONTEXT), .TUSER_T(tuser_buffer_context_mode_t)) axi4s_hdr_out();

    // axi4s_split_join instantiation.
    axi4s_split_join #(
      .BIGENDIAN (BIGENDIAN)
    ) DUT (
      .axi4s_in      (axi4s_in),
      .axi4s_out     (axi4s_out),
      .axi4s_hdr_in  (axi4s_hdr_in),
      .axi4s_hdr_out (axi4s_hdr_out),
      .hdr_length    (hdr_slice_length)
    );

//    axi4s_intf_connector axi4s_intf_connector_0 (.axi4s_from_tx(axi4s_in), .axi4s_to_rx(axi4s_out));   

   // axi4s header processor instantiation.
   axi4s_hdr_proc #(
      .BIGENDIAN (BIGENDIAN),
      .DATA_BYTE_WID(DATA_BYTE_WID)
   ) axi4s_hdr_proc_0 ( 
      .axi4s_in          (axi4s_hdr_out),
      .axi4s_out         (axi4s_hdr_in),
      .drop_hdr          (drop_hdr),
      .prefix            (prefix),
      .hdr_trunc_length  (hdr_trunc_length)
   );

/*
    // Monitor output interface - display packet data.                                                                                                                      
    always @(posedge axi4s_out.aclk) begin
       if (axi4s_out.tready && axi4s_out.tvalid) begin
          $display("tdata: %h  tlast: %h", axi4s_out.tdata, axi4s_out.tlast);
       end
    end
*/


    //===================================
    // Testbench
    //===================================
    axi4s_component_env #(
        DATA_BYTE_WID,
        TID_T,
        TDEST_T,
        TUSER_T
    ) env;

    // Model
    std_verif_pkg::wire_model#(AXI4S_TRANSACTION_T) model;
    std_verif_pkg::event_scoreboard#(AXI4S_TRANSACTION_T) scoreboard;

    // Reset
    std_reset_intf reset_if (.clk(axi4s_in.aclk));
    assign axi4s_in.aresetn = !reset_if.reset;
    assign reset_if.ready = !reset_if.reset;

    // Assign clock (333MHz)
    `SVUNIT_CLK_GEN(axi4s_in.aclk, 10ns);

    //===================================
    // Build
    //===================================
    function void build();

        svunit_ut = new(name);

        model = new();
        scoreboard = new();

        env = new("env", model, scoreboard, BIGENDIAN);
        env.reset_vif = reset_if;
        env.axis_in_vif = axi4s_in;
        env.axis_out_vif = axi4s_out;
        env.connect();

        env.set_debug_level(0);
    endfunction


    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();

        // Reset environment
        env.reset();

        // Put interfaces in quiescent state
        env.idle();

        // Issue reset
        env.reset_dut();

        // Start environment
        env.start();

        // empty prefix array (size = 0)
        prefix.delete();

        // empty drop_hdr array (size = 0)
        drop_hdr.delete();

        repeat(100) @(posedge axi4s_in.aclk); // init fifos?
    endtask


    //===================================
    // Here we deconstruct anything we 
    // need after running the Unit Tests
    //===================================
    task teardown();
        svunit_ut.teardown();

        // Stop environment
        env.stop();
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
    string msg;

    packet_raw packet;
    AXI4S_TRANSACTION_T axis_transaction;
            
    byte hdr_in  [];
    byte pyld_in [];
    byte hdr_exp [];

    // header data
    byte hdr_data      [] = {>>byte{'h0001020304050607_08090a0b0c0d0e0f}};

    // payload data
    byte pyld_data     [] = {>>byte{'hf0f1f2f3f4f5f6f7_f8f9fafbfcfdfeff_e0e1e2e3e4e5e6e7_e8e9eaebecedeeef}};

    int tpause;



    task packet_loop;
       // set header slice size (used by DUT) to 16B.  hdr_slice_length MUST be a multiple of DATA_BYTE_WID.
       hdr_slice_length = 16;

       // iterate payload from 0B to 32B (3B increments).
       for (int j = 0; j <= 32; j=j+3) begin
          // iterate header truncation (used by header processor ie. axi4s_trunc_0) from 1B to 16B.
          for (int i = 1; i <= 16; i++) begin
              // build packet headers and payload (input and expected).
              hdr_in = new[hdr_data.size()];
              hdr_in = hdr_data;
              
              pyld_in = new[j];
              for (int k = 0; k < j; k++) pyld_in[k] = pyld_data[k];

              hdr_exp = new[i];
              for (int k = 0; k < i; k++) hdr_exp[k] = hdr_in[k];

              // set header processing truncation length.
              hdr_trunc_length = i+prefix.size();

              // build and launch expected packet (hdr_exp + pyld_in).
              packet = new();
              packet = packet.create_from_bytes($sformatf("pkt_exp_%0d_%0d", i, j), {prefix, hdr_exp, pyld_in});
              axis_transaction = new($sformatf("trans_exp_%0d_%0d", i, j), packet);
              env.model.inbox.put(axis_transaction);

              // build and launch input packet (hdr_in + pyld_in).
              packet = new();
              packet = packet.create_from_bytes($sformatf("pkt_in_%0d_%0d", i, j), {hdr_in, pyld_in});
              axis_transaction = new($sformatf("trans_in_%0d_%0d", i, j), packet);
              env.driver.inbox.put(axis_transaction);

              // wait for packet transit time.
              wait(axi4s_out.tready && axi4s_out.tvalid && axi4s_out.tlast); axi4s_out._wait(3);
          end

          // if drop_hdr is set, send packet that will be dropped (before looping to increment payload size).
          if (drop_hdr.size() != 0) begin
            hdr_trunc_length = 16; // set header processing truncation length to 16B.
            packet = new();
            packet = packet.create_from_bytes($sformatf("pkt_in_drop_%0d", j), {drop_hdr, pyld_in});
            axis_transaction = new($sformatf("trans_in_drop_%0d", j), packet);
            env.driver.inbox.put(axis_transaction);

            axi4s_out._wait(100); // wait for packet transit time.
          end

        end

       `FAIL_IF_LOG (scoreboard.report(msg) != 0, msg); `INFO(msg);
    endtask


    `SVUNIT_TESTS_BEGIN

        `SVTEST(shrink_header)
            // leave prefix undefined i.e. no header growth.

            // send sequence of packets that iteratively shorten original header.
            packet_loop;

        `SVTEST_END

        `SVTEST(grow_header)
            // set header prefix (used by header processor) to grow header by 16B.
            prefix = {>>byte{'h0011223344556677_8899aabbccddeeff}};

            // send sequence of packets that iteratively shorten original header.
            packet_loop;

        `SVTEST_END

        `SVTEST(shrink_header_with_drops)
            // set drop header.
            drop_hdr = {>>byte{'h9696969696969696_9696969696969696}};

            // send sequence of packets that shorten original header.
            packet_loop;

        `SVTEST_END

        `SVTEST(shrink_header_with_stalls)
            fork
               // send sequence of packets that iteratively shorten original header.
               packet_loop;

               // tpause logic - overrides axi4s_out.tready signal (to model intermittent backpressure)
               forever begin
                  @(posedge axi4s_out.aclk);
                  if (axi4s_out.tready && axi4s_out.tvalid) begin
                     tpause = $urandom_range(3);
                     if (tpause > 0) force axi4s_out.tready = '0;
                  end else if (tpause == 0) begin
                     force axi4s_out.tready = '1;
                  end else tpause <= tpause - 1;
               end
            join_any

        `SVTEST_END


    `SVUNIT_TESTS_END

endmodule




// -----------------------------------------------------------------------------
// axi4s_hdr_proc includes rudimentary header processing functions, for test
// purposes.  It includes:
//
// (i) logic to flag and shorten the headers of packets that should be dropped,
// (ii) a block that appends a specified prefix to each packet (increases hdr size),
// (iii) a block that truncates packets to a specicifed size (shortens hdr size),
// (iv) a fifo to buffer the processed header stream.
//
// testcases can activate any of these features (together or independently) to
// exercise specific testcase scenarios.
// -----------------------------------------------------------------------------
module axi4s_hdr_proc
   import axi4s_pkg::*;
#(
   parameter int BIGENDIAN = 0,
   parameter int DATA_BYTE_WID = 16
) ( 
   axi4s_intf.rx       axi4s_in,
   axi4s_intf.tx       axi4s_out,

   input byte drop_hdr [],
   input byte prefix [],
   input int  hdr_trunc_length
);

   // local axi4s interface instantiations
   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TUSER_MODE(BUFFER_CONTEXT), .TUSER_T(tuser_buffer_context_mode_t)) axi4s_to_prefix();
   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TUSER_MODE(BUFFER_CONTEXT), .TUSER_T(tuser_buffer_context_mode_t)) axi4s_to_trunc();
   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TUSER_MODE(BUFFER_CONTEXT), .TUSER_T(tuser_buffer_context_mode_t)) axi4s_to_fifo();


   assign axi4s_in.tready = axi4s_to_prefix.tready;

   // drop header logic
   logic  drop_pkt;
   always @(*) begin
      drop_pkt = axi4s_in.sop && drop_hdr.size() != 0;
      for (int i = 0; i < DATA_BYTE_WID; i++) drop_pkt = drop_pkt && axi4s_in.tdata[i] == drop_hdr[i]; 
   end

   logic drop_pkt_latch;
   always @(posedge axi4s_in.aclk)
      if (!axi4s_in.aresetn)                                         drop_pkt_latch <= '0;
      else if (axi4s_in.tvalid && axi4s_in.tready && axi4s_in.tlast) drop_pkt_latch <= '0;
      else if (drop_pkt)                                             drop_pkt_latch <= '1;

   assign axi4s_to_prefix.aclk    = axi4s_in.aclk;
   assign axi4s_to_prefix.aresetn = axi4s_in.aresetn;
   assign axi4s_to_prefix.tvalid  = drop_pkt_latch ? '0 : axi4s_in.tvalid;
   assign axi4s_to_prefix.tdata   = axi4s_in.tdata;
   assign axi4s_to_prefix.tkeep   = drop_pkt ? '0 : axi4s_in.tkeep;
   assign axi4s_to_prefix.tlast   = drop_pkt ? '1 : axi4s_in.tlast;
   assign axi4s_to_prefix.tid     = axi4s_in.tid;
   assign axi4s_to_prefix.tdest   = axi4s_in.tdest;
   assign axi4s_to_prefix.tuser   = axi4s_in.tuser;


   // axi4s_prefix instance.
   axi4s_prefix #(
      .BIGENDIAN (BIGENDIAN)
   ) axi4s_prefix_0 ( 
      .axi4s_in   (axi4s_to_prefix),
      .axi4s_out  (axi4s_to_trunc),
      .prefix     (prefix)
   );


   // axi4s_trunc instance.
   axi4s_trunc #(
      .BIGENDIAN (BIGENDIAN)
   ) axi4s_trunc_0 (
      .axi4s_in   (axi4s_to_trunc),
      .axi4s_out  (axi4s_to_fifo),
      .length     (hdr_trunc_length)
   );


   // instantiate and terminate unused AXI-L interfaces.
   axi4l_intf axil_to_probe ();
   axi4l_intf axil_to_ovfl  ();
   axi4l_intf axil_to_fifo  ();

   axi4l_intf_controller_term axi4l_to_probe_term (.axi4l_if (axil_to_probe));
   axi4l_intf_controller_term axi4l_to_ovfl_term  (.axi4l_if (axil_to_ovfl));
   axi4l_intf_controller_term axi4l_to_fifo_term  (.axi4l_if (axil_to_fifo));

   // header fifo instantiation.
   axi4s_pkt_fifo_sync #(
      .FIFO_DEPTH(128)
   ) fifo_0 (
      .axi4s_in       (axi4s_to_fifo),
      .axi4s_out      (axi4s_out),
      .axil_to_probe  (axil_to_probe),
      .axil_to_ovfl   (axil_to_ovfl),
      .axil_if        (axil_to_fifo)
    );

endmodule 



// -----------------------------------------------------------------------------
// axi4s_prefix is used to add a prefix to an incoming packet (for test purposes).
// prefix size can be variable, but must be an integer number of words.
// -----------------------------------------------------------------------------
module axi4s_prefix
   import axi4s_pkg::*;
#(
   parameter int BIGENDIAN = 0
) ( 
   axi4s_intf.rx       axi4s_in,
   axi4s_intf.tx       axi4s_out,

   input byte prefix []
);

   localparam int  DATA_BYTE_WID = axi4s_in.DATA_BYTE_WID;
   localparam type TID_T         = axi4s_in.TID_T;
   localparam type TDEST_T       = axi4s_in.TDEST_T;
   localparam type TUSER_T       = axi4s_in.TUSER_T;

   axi4s_intf #(.DATA_BYTE_WID(DATA_BYTE_WID), .TID_T(TID_T), .TDEST_T(TDEST_T), .TUSER_T(TUSER_T)) axi4s_pipe ();

   // axi4s pipe stage.
   axi4s_intf_pipe axi4s_in_pipe (
      .axi4s_if_from_tx (axi4s_in),
      .axi4s_if_to_rx   (axi4s_pipe)
   );

   logic [15:0] index;
   logic        add_prefix;

   int prefix_size;
   //assign prefix_size = prefix.size();
   always @(posedge axi4s_out.aclk) prefix_size = prefix.size();

   assign add_prefix = (prefix_size != 0) && (index < (prefix_size/DATA_BYTE_WID));

   // output word index logic
   always @(posedge axi4s_out.aclk)
      if (!axi4s_out.aresetn)       index <= '0;
      else if (axi4s_out.tvalid && axi4s_out.tready) 
         if (add_prefix)            index <= index + 1;
         else if (axi4s_out.tlast)  index <= '0;

   logic [DATA_BYTE_WID-1:0][7:0] prefix_tdata;
   always @(*) begin
      for (int i=0; i<DATA_BYTE_WID; i++)
         if (BIGENDIAN) prefix_tdata[DATA_BYTE_WID-1-i] = prefix[(index*DATA_BYTE_WID)+i];
         else           prefix_tdata[i]                 = prefix[(index*DATA_BYTE_WID)+i];
   end

   // axis4s input interface signalling.
   assign axi4s_pipe.tready = axi4s_out.tready && !add_prefix;

   // axis4s output 0 interface signalling.
   assign axi4s_out.aclk    = axi4s_pipe.aclk;
   assign axi4s_out.aresetn = axi4s_pipe.aresetn;
   assign axi4s_out.tvalid  = axi4s_pipe.tvalid;
   assign axi4s_out.tdata   = add_prefix ? prefix_tdata : axi4s_pipe.tdata;
   assign axi4s_out.tkeep   = add_prefix ?           '1 : axi4s_pipe.tkeep;
   assign axi4s_out.tlast   = add_prefix ?           '0 : axi4s_pipe.tlast;
   assign axi4s_out.tid     = axi4s_pipe.tid;
   assign axi4s_out.tdest   = axi4s_pipe.tdest;
   assign axi4s_out.tuser   = axi4s_pipe.tuser;

endmodule // axi4s_prefix






// 'Boilerplate' unit test wrapper code
//  Builds unit test for a specific axi4s_split_join configuration in a way
//  that maintains SVUnit compatibility

`define AXI4S_SPLIT_JOIN_UNIT_TEST(DATA_BYTE_WID)\
  import svunit_pkg::svunit_testcase;\
  svunit_testcase svunit_ut;\
  axi4s_split_join_unit_test #(DATA_BYTE_WID) test();\
  function void build();\
    test.build();\
    svunit_ut = test.svunit_ut;\
  endfunction\
  task run();\
    test.run();\
  endtask


module axi4s_split_join_datawidth_2_unit_test;
`AXI4S_SPLIT_JOIN_UNIT_TEST(2)
endmodule

module axi4s_split_join_datawidth_4_unit_test;
`AXI4S_SPLIT_JOIN_UNIT_TEST(4)
endmodule

module axi4s_split_join_datawidth_8_unit_test;
`AXI4S_SPLIT_JOIN_UNIT_TEST(8)
endmodule

module axi4s_split_join_datawidth_16_unit_test;
`AXI4S_SPLIT_JOIN_UNIT_TEST(16)
endmodule
