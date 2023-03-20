package db_pkg;

    // -----------------------------
    // Typedefs
    // -----------------------------
    typedef enum logic[7:0] {
        DB_TYPE_UNSPECIFIED = 0,
        DB_TYPE_STASH       = 1,
        DB_TYPE_HTABLE      = 2,
        DB_TYPE_STATE       = 3
    } type_t;

    typedef logic[7:0] subtype_t;

    typedef enum subtype_t {
        DB_STASH_TYPE_UNSPECIFIED = 0,
        DB_STASH_TYPE_STANDARD = 1,
        DB_STASH_TYPE_LRU = 2,
        DB_STASH_TYPE_FIFO = 3
    } stash_subtype_t;

    typedef enum logic [2:0] {
        COMMAND_NOP,
        COMMAND_GET,
        COMMAND_GET_NEXT,
        COMMAND_SET,
        COMMAND_UNSET,
        COMMAND_UNSET_NEXT,
        COMMAND_REPLACE,
        COMMAND_CLEAR
    } command_t;

    typedef enum logic [1:0] {
        STATUS_UNSPECIFIED,
        STATUS_OK,
        STATUS_ERROR,
        STATUS_TIMEOUT
    } status_t;

endpackage : db_pkg

