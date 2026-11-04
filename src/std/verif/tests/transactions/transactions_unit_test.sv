`include "svunit_defines.svh"

module transactions_unit_test;
    import svunit_pkg::svunit_testcase;
    import std_verif_pkg::*;
    import std_verif_test_pkg::*;

    string name = "transactions_ut";
    svunit_testcase svunit_ut;

    //===================================
    // Build / setup / teardown
    //===================================
    function void build(); svunit_ut = new(name); endfunction
    task setup(); svunit_ut.setup(); endtask
    task teardown(); svunit_ut.teardown(); endtask

    //===================================
    // Tests
    //===================================
    `SVUNIT_TESTS_BEGIN
        `SVTEST(name_and_debug_level)
            word_t item = new("original", 32'h1234);
            `FAIL_UNLESS_STR_EQUAL(item.get_name(), "original");
            `FAIL_UNLESS_EQUAL(item.get_debug_level(), 0);
            item.set_name("renamed");
            item.set_debug_level(2);
            `FAIL_UNLESS_STR_EQUAL(item.get_name(), "renamed");
            `FAIL_UNLESS_EQUAL(item.get_debug_level(), 2);
            item.set_name("");
            `FAIL_UNLESS_STR_EQUAL(item.get_name(), "");
        `SVTEST_END

        `SVTEST(copy_is_independent)
            word_t source = new("source", 32'h12345678);
            word_t copied = new("destination", 0);
            source.set_debug_level(1);
            copied.copy(source);
            source.data = 0;
            source.set_name("changed");
            source.set_debug_level(0);
            `FAIL_UNLESS_EQUAL(copied.data, 32'h12345678);
            `FAIL_UNLESS_STR_EQUAL(copied.get_name(), "source");
            `FAIL_UNLESS_EQUAL(copied.get_debug_level(), 1);
        `SVTEST_END

        `SVTEST(clone_preserves_dynamic_type)
            word_t source = new("source", 32'habcdef01);
            transaction cloned_base;
            word_t cloned;
            cloned_base = source.clone();
            `FAIL_UNLESS($cast(cloned, cloned_base));
            `FAIL_IF(cloned == source);
            source.data = 0;
            source.set_name("changed");
            `FAIL_UNLESS_EQUAL(cloned.data, 32'habcdef01);
            `FAIL_UNLESS_STR_EQUAL(cloned.get_name(), "source");
        `SVTEST_END

        `SVTEST(compare_equal_mismatch_and_type)
            word_t a = new("a", 32'h1234);
            word_t b = new("b", 32'h1234);
            byte_t other_type = new("byte", 8'h34);
            string msg;
            `FAIL_UNLESS(a.compare(b, msg));
            b.data++;
            `FAIL_IF(a.compare(b, msg));
            `FAIL_UNLESS(msg.len() > 0);
            `FAIL_IF(a.compare(other_type, msg));
            `FAIL_UNLESS(msg.len() > 0);
        `SVTEST_END

        `SVTEST(format_and_destroy)
            word_t item = new("example", 32'h1234);
            `FAIL_UNLESS_STR_EQUAL(item.to_string(), "Raw transaction 'example': 0x1234\n");
            item.destroy();
        `SVTEST_END
    `SVUNIT_TESTS_END
endmodule
