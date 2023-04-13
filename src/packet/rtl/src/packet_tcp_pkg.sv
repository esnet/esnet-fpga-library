package packet_tcp_pkg;

    //===================================
    // Parameters
    //===================================
    localparam int SEQ_WID = 32;

    //===================================
    // Typedefs
    //===================================
    typedef logic [SEQ_WID-1:0] seq_t;

endpackage : packet_tcp_pkg
