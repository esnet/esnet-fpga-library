package axi3_pkg;

    // ------------------------
    // Typedefs
    // ------------------------

    // BRESP/RRESP
    typedef enum logic [1:0] {
        RESP_OKAY = 2'b00,
        RESP_EXOKAY = 2'b01,
        RESP_SLVERR = 2'b10,
        RESP_DECERR = 2'b11
    } resp_encoding_t;

    typedef union packed {
        resp_encoding_t encoded;
        logic [1:0]     raw;
    } resp_t;

    // AxSIZE
    typedef enum logic [2:0] {
        SIZE_1BYTE = 3'b000,
        SIZE_2BYTES = 3'b001,
        SIZE_4BYTES = 3'b010,
        SIZE_8BYTES = 3'b011,
        SIZE_16BYTES = 3'b100,
        SIZE_32BYTES = 3'b101,
        SIZE_64BYTES = 3'b110,
        SIZE_128BYTES = 3'b111
    } axsize_encoding_t;

    typedef union packed {
        axsize_encoding_t encoded;
        logic [2:0]       raw;
    } axsize_t;

    // AxBURST
    typedef enum logic [1:0] {
        BURST_FIXED = 2'b00,
        BURST_INCR = 2'b01,
        BURST_WRAP = 2'b10,
        BURST_RSVD = 2'b11
    } axburst_encoding_t;

    typedef union packed {
        axburst_encoding_t encoded;
        logic [1:0]        raw;
    } axburst_t;

    // AxLOCK
    typedef enum logic [1:0] {
        LOCK_NORMAL = 2'b00,
        LOCK_EXCLUSIVE = 2'b01,
        LOCK_LOCKED = 2'b10,
        LOCK_RSVD = 2'b11
    } axlock_encoding_t;

    typedef union packed {
        axlock_encoding_t encoded;
        logic [1:0]       raw;
    } axlock_t;

    // AxCACHE
    typedef struct packed {
        logic bufferable;
        logic cacheable;
        logic read_allocate;
        logic write_allocate;
    } axcache_encoding_t;

    typedef union packed {
        axcache_encoding_t encoded;
        logic [3:0]        raw;
    } axcache_t;

    // AxPROT
    typedef struct packed {
        logic instruction_data_n;
        logic secure;
        logic privileged;
    } axprot_encoding_t;

    typedef union packed {
        axprot_encoding_t encoded;
        logic [2:0]       raw;
    } axprot_t;

    // ------------------------
    // Functions
    // ------------------------
    function automatic int get_word_size(input axsize_t axsize);
        case (axsize.encoded)
            SIZE_1BYTE    : return 1;
            SIZE_2BYTES   : return 2;
            SIZE_4BYTES   : return 4;
            SIZE_8BYTES   : return 8;
            SIZE_16BYTES  : return 16;
            SIZE_32BYTES  : return 32;
            SIZE_64BYTES  : return 64;
            SIZE_128BYTES : return 128;
        endcase
    endfunction

endpackage : axi3_pkg
