package htable_pkg;

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef enum logic[7:0] {
        HTABLE_TYPE_UNSPECIFIED = 0,
        HTABLE_TYPE_SINGLE,
        HTABLE_TYPE_MULTI,
        HTABLE_TYPE_MULTI_STASH,
        HTABLE_TYPE_CUCKOO,
        HTABLE_TYPE_CUCKOO_FAST_UPDATE
    } htable_type_t;

    // Generic hash data type
    // - width is picked to accommodate any practical
    //   hash implementation, where hash is used to
    //   index into tables
    // - e.g. 32-bit hash supports hash table depths
    //        up to 4G entries
    typedef logic [31:0] hash_t;

    typedef enum {
        HTABLE_MULTI_INSERT_MODE_NONE,
        HTABLE_MULTI_INSERT_MODE_ROUND_ROBIN,
        HTABLE_MULTI_INSERT_MODE_BROADCAST
    } htable_multi_insert_mode_t;

endpackage : htable_pkg
