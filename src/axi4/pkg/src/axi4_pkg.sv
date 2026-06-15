package axi4_pkg;

    // ------------------------
    // Typedefs
    // ------------------------

    // BRESP/RRESP
    typedef enum logic [1:0] {
        RESP_OKAY   = 2'b00,
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
        SIZE_1BYTE   = 3'b000,
        SIZE_2BYTES  = 3'b001,
        SIZE_4BYTES  = 3'b010,
        SIZE_8BYTES  = 3'b011,
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
        BURST_INCR  = 2'b01,
        BURST_WRAP  = 2'b10,
        BURST_RSVD  = 2'b11
    } axburst_encoding_t;

    typedef union packed {
        axburst_encoding_t encoded;
        logic [1:0]        raw;
    } axburst_t;

    // AxLOCK (AXI4: 1 bit; AXI3 used 2 bits)
    typedef enum logic {
        LOCK_NORMAL    = 1'b0,
        LOCK_EXCLUSIVE = 1'b1
    } axlock_encoding_t;

    typedef union packed {
        axlock_encoding_t encoded;
        logic             raw;
    } axlock_t;

    // AxCACHE
    typedef struct packed {
        logic write_allocate;
        logic read_allocate;
        logic cacheable;
        logic bufferable;
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

endpackage : axi4_pkg
