package sync_pkg;

    // Parameters
    localparam int RETIMING_STAGES = 3;

    // Typedefs
    typedef enum {
        HANDSHAKE_MODE_4PHASE,
        HANDSHAKE_MODE_2PHASE
    } handshake_mode_t;

endpackage : sync_pkg
