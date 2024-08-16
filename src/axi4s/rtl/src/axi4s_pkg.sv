package axi4s_pkg;
   
    typedef enum logic {
        STANDARD,
        IGNORES_TREADY
    } axi4s_mode_t;

    typedef enum int {
        USER,
        PKT_ERROR
    } axi4s_tuser_mode_t;

    typedef enum int {
        GOOD,
        OVFL,
        ERRORS
    } axi4s_probe_mode_t;

    typedef enum int {
        PULL,
        PUSH
    } axi4s_pipe_mode_t;

    typedef enum int {
        SOP,
        HDR_TLAST
    } axi4s_sync_mode_t;

    typedef struct packed {
        logic [8:0]  pid;
        logic        hdr_tlast;
    } tuser_split_join_t;

endpackage : axi4s_pkg
