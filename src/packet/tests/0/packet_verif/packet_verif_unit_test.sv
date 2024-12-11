`include "svunit_defines.svh"

module packet_verif_unit_test;
    import svunit_pkg::svunit_testcase;
    import packet_verif_pkg::*;

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

        `SVTEST(_packet_raw)
            int exp_size = payload_data.size();
            packet_pkg::protocol_t exp_protocol = packet_pkg::PROTOCOL_NONE;

            // Create new raw packet from payload data
            packet_raw#() the_raw_packet = packet_raw#()::create_from_bytes("raw packet", payload_data);

            // Print packet
            $display(the_raw_packet.to_string());

            // Check protocol
            `FAIL_UNLESS_LOG(
                the_raw_packet.protocol() == exp_protocol,
                $sformatf(
                    "Protocol mismatch. Exp: %s, Got: %s",
                    exp_protocol.name,
                    the_raw_packet.protocol().name,
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

        `SVTEST(_packet_eth)
            packet_raw#() the_payload;
            packet_eth the_eth_packet;
            int exp_size = packet_eth_pkg::HDR_BYTES + payload_data.size();
            packet_pkg::protocol_t exp_protocol = packet_pkg::PROTOCOL_ETHERNET;

            // Create new payload (raw packet)
            the_payload = packet_raw#()::create_from_bytes("the payload", payload_data);

            // Create new Ethernet packet
            the_eth_packet = new("the eth packet", eth_hdr, the_payload);

            // Print packet
            $display(the_eth_packet.to_string());

            // Check protocol
            `FAIL_UNLESS_LOG(
                the_eth_packet.protocol() == exp_protocol,
                $sformatf(
                    "Protocol mismatch. Exp: %s, Got: %s",
                    exp_protocol.name,
                    the_eth_packet.protocol().name
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

        `SVTEST(random_packet)
            typedef logic[31:0] meta_t;
            packet_raw#(meta_t) rand_pkt;
            int len=$urandom_range(256,512);
            meta_t meta;
            void'(std::randomize(meta));
            rand_pkt = new("random packet", len, meta);
            rand_pkt.randomize();
            // Check results of packet randomization
            $display(rand_pkt.to_string());
            `FAIL_UNLESS_EQUAL(rand_pkt.size(), len);
            `FAIL_UNLESS_EQUAL(rand_pkt.get_meta(), meta);
        `SVTEST_END

        `SVTEST(clone)
            typedef logic[22:0] meta_t;
            int len=$urandom_range(64, 1500);
            int bad_byte_idx = $urandom_range(0, len);
            meta_t meta;
            string msg;
            packet_raw#(meta_t) ref_pkt;
            packet#(meta_t) cloned_pkt;
            // Create (randomized) reference packet
            ref_pkt = new("reference", len);
            ref_pkt.randomize();
            void'(std::randomize(meta));
            ref_pkt.set_meta(meta);
            // Clone reference packet, and upcast to packet type
            $cast(cloned_pkt, ref_pkt.clone());
            cloned_pkt.set_name("clone");
            `FAIL_UNLESS_LOG(cloned_pkt.compare(ref_pkt, msg), msg);
            // Modify clone; expect error
            cloned_pkt.set_byte(bad_byte_idx, 8'hff ^ cloned_pkt.get_byte(bad_byte_idx));
            `FAIL_IF_LOG(cloned_pkt.compare(ref_pkt, msg), msg);
        `SVTEST_END

        `SVTEST(dup)
            typedef logic[22:0] meta_t;
            int len=$urandom_range(64, 1500);
            int bad_byte_idx = $urandom_range(0, len);
            meta_t meta;
            string msg;
            packet_raw#(meta_t) ref_pkt;
            packet#(meta_t) dup_pkt;
            // Create (randomized) reference packet
            ref_pkt = new("reference", len);
            ref_pkt.randomize();
            void'(std::randomize(meta));
            ref_pkt.set_meta(meta);
            // Duplicate reference packet (no need for cast)
            dup_pkt = ref_pkt.dup("duplicate");
            `FAIL_UNLESS_LOG(dup_pkt.compare(ref_pkt, msg), msg);
            // Modify duplicate; expect error
            dup_pkt.set_byte(bad_byte_idx, 8'hff ^ dup_pkt.get_byte(bad_byte_idx));
            `FAIL_IF_LOG(dup_pkt.compare(ref_pkt, msg), msg);
        `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
