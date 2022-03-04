`include "svunit_defines.svh"

module packet_verif_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "packet_verif_ut";
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

        `SVTEST(packet_raw)
            import packet_verif_pkg::*;
            int exp_size = payload_data.size();
        
            // Create new raw packet from payload data
            packet_raw the_raw_packet = new("raw packet", payload_data);

            // Print packet
            $display(the_raw_packet.to_string());

            // Check protocol
            `FAIL_UNLESS_LOG(
                the_raw_packet.protocol() == packet_pkg::PROTOCOL_NONE,
                $sformatf(
                    "Protocol mismatch. Exp: %s, Got: %s",
                    the_raw_packet.protocol().name,
                    packet_pkg::PROTOCOL_NONE.name
                )
            );

            // Check size
            `FAIL_UNLESS_LOG(
                the_raw_packet.size() == exp_size,
                $sformatf(
                    "Packet size mismatch. Exp: %0d bytes, Got: %0d bytes",
                    the_raw_packet.size(),
                    exp_size
                )
            );

        `SVTEST_END

        `SVTEST(packet_eth)
            import packet_verif_pkg::*;
            packet_raw the_payload;
            packet_eth the_eth_packet;
            int exp_size = packet_eth_pkg::HDR_BYTES + payload_data.size();
 
            // Create new payload (raw packet)
            the_payload = new("the payload", payload_data);
            
            // Create new Ethernet packet
            the_eth_packet = new("the eth packet", eth_hdr, the_payload);

            // Print packet
            $display(the_eth_packet.to_string());

            // Check protocol
            `FAIL_UNLESS_LOG(
                the_eth_packet.protocol() == packet_pkg::PROTOCOL_ETHERNET,
                $sformatf(
                    "Protocol mismatch. Exp: %s, Got: %s",
                    the_eth_packet.protocol().name,
                    packet_pkg::PROTOCOL_ETHERNET.name
                )
            );

            // Check size
            `FAIL_UNLESS_LOG(
                the_eth_packet.size() == exp_size,
                $sformatf(
                    "Packet size mismatch. Exp: %0d bytes, Got: %0d bytes",
                    the_eth_packet.size(),
                    exp_size
                )
            );

        `SVTEST_END
    
    `SVUNIT_TESTS_END

endmodule
