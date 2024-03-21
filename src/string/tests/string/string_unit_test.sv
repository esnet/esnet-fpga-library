`include "svunit_defines.svh"

module string_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "string_ut";
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
    // Tests
    //===================================

    // Test vectors
    byte int_byte_array [] = '{
        65,  66,   67,  32,
        100, 101, 102,  32,
        71,  72,   73,  32,
        106, 107, 108,  32,
        77,  78,   79,  32,
        112, 113, 114,  32,
        83,  84,   85,  32,
        118, 119, 120,  32,
        89,  90,   46,  32
    };

    const byte ascii_byte_array [] = '{
        "A", "B", "C", " ",
        "d", "e", "f", " ",
        "G", "H", "I", " ",
        "j", "k", "l", " ",
        "M", "N", "O", " ",
        "p", "q", "r", " ",
        "S", "T", "U", " ",
        "v", "w", "x", " ",
        "Y", "Z", ".", " "
    };

    const string ascii_string = "ABC def GHI jkl MNO pqr STU vwx YZ. ";

    byte hex_byte_array [] = '{
        'h41, 'h42, 'h43, 'h20,
        'h64, 'h65, 'h66, 'h20,
        'h47, 'h48, 'h49, 'h20,
        'h6a, 'h6b, 'h6c, 'h20,
        'h4d, 'h4e, 'h4f, 'h20,
        'h70, 'h71, 'h72, 'h20,
        'h53, 'h54, 'h55, 'h20,
        'h76, 'h77, 'h78, 'h20,
        'h59, 'h5a, 'h2e, 'h20
    };

    const string hex_string = "4142432064656620474849206a6b6c204d4e4f20707172205354552076777820595a2e20";

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
    `SVUNIT_TESTS_BEGIN

    `SVTEST(byte_array_to_hex_string)
        import string_pkg::*;
        string got_string;
        string exp_string = hex_string;

        // Convert byte array to hex string
        got_string = byte_array_to_hex_string(int_byte_array);

        // Check
        `FAIL_UNLESS_LOG(
            got_string == exp_string,
            $sformatf(
                "Mismatch.\nExp: %s\nGot: %s",
                exp_string,
                got_string
            )
        );
    `SVTEST_END

    `SVTEST(byte_array_to_ascii_string)
        import string_pkg::*;
        string got_string;
        string exp_string = ascii_string;

        // Convert byte array to ASCII string
        got_string = byte_array_to_ascii_string(int_byte_array);

        // Check
        `FAIL_UNLESS_LOG(
            got_string == exp_string,
            $sformatf(
                "Mismatch.\nExp: %s\nGot: %s",
                exp_string,
                got_string
            )
        );
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
