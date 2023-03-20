package packet_ip_pkg;

    //===================================
    // Parameters
    //===================================
    localparam int VERSION_WID = 4;

    //===================================
    // Typedefs
    //===================================
    typedef enum logic [VERSION_WID-1:0] {
        VERSION_IPV4 = 4,
        VERSION_IPV6 = 6
    } version_t;

endpackage : packet_ip_pkg
