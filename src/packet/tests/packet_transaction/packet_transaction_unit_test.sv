`include "svunit_defines.svh"

module packet_transaction_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "packet_transaction_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Build
    //===================================
    function void build();
        svunit_ut = new(name);
    endfunction


    //===================================
    // Setup for running the Unit Tests
    //===================================
    task setup();
        svunit_ut.setup();
        /* Place Setup Code Here */

    endtask


    //===================================
    // Here we deconstruct anything we
    // need after running the Unit Tests
    //===================================
    task teardown();
        svunit_ut.teardown();
        /* Place Teardown Code Here */

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
    // Payload
    byte payload_data [] = '{"H", "e", "l", "l", "o", ",", " ", "W", "o", "r", "l", "d", "!", "!", "!", "!"};        

    // Ethernet header
    packet_eth_pkg::hdr_t eth_hdr = '{
        dst_addr : 'h001122334455,
        src_addr : 'haabbccddeeff,
        eth_type : 'h0800
    };

    `SVUNIT_TESTS_BEGIN

        `SVTEST(packet_raw_transaction)
            import packet_verif_pkg::*;
            packet_raw the_raw_packet;
            packet_transaction the_transaction;

            // Create raw packet
            the_raw_packet = new("the raw packet", payload_data);

            // Create transaction from packet
            the_transaction = new("the packet transaction", the_raw_packet);

            // Print transaction
            $display(the_transaction.to_string());

        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
