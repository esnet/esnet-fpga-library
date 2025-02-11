package sar_pkg;

    // -----------------------------
    // Typedefs
    // -----------------------------
    // Payload modes
    typedef enum {
        PAYLOAD_MODE_DIRECT,        // Payload data is stored directly;
                                    //   i.e. it is assembled in memory as it is received, based on offset.
        PAYLOAD_MODE_SCATTER_GATHER // Payload data is managed using a scatter-gather scheme; 
                                    //   i.e it is written to an arbitrary address when it is received and referenced by a descriptor.
    } payload_mode_t;

    typedef enum logic {
        REASSEMBLY_NOTIFY_EXPIRED,
        REASSEMBLY_NOTIFY_DONE
    } reassembly_notify_type_t;
    
endpackage : sar_pkg
