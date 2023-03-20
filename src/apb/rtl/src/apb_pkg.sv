package apb_pkg;

    // ------------------------
    // Typedefs
    // ------------------------
    // PPROT
    typedef struct packed {
        logic instruction_data_n;
        logic secure;
        logic privileged;
    } pprot_encoding_t;

    typedef union packed {
        pprot_encoding_t encoded;
        logic [2:0]      raw;
    } pprot_t;

    localparam pprot_encoding_t PPROT_ENCODING_DEFAULT = '{privileged: 1'b0, secure: 1'b0, instruction_data_n: 1'b0};
    localparam pprot_t PPROT_DEFAULT = PPROT_ENCODING_DEFAULT;

endpackage : apb_pkg
