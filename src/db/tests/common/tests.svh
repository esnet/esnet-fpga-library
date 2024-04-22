    `SVTEST(hard_reset)
    `SVTEST_END

    `SVTEST(info)
        db_pkg::type_t got_type;
        db_pkg::subtype_t got_subtype;
        int got_size;
        // Get info and check against expected
        agent.get_type(got_type);
        `FAIL_UNLESS_EQUAL(got_type, DB_TYPE);

        agent.get_subtype(got_subtype);
        `FAIL_UNLESS_EQUAL(got_subtype, DB_SUBTYPE);

        agent.get_size(got_size);
        `FAIL_UNLESS_EQUAL(got_size, SIZE);
    `SVTEST_END

