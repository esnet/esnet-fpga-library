package packet_eth_pkg;

    //===================================
    // Parameters
    //===================================
    localparam int ADDR_WID = 48;
    localparam int ETHERTYPE_WID = 16;

    //===================================
    // Typedefs
    //===================================
    typedef logic [ADDR_WID-1:0]      addr_t;
    typedef logic [ETHERTYPE_WID-1:0] ethertype_t;

    // MAC header specification
    typedef struct packed {
        addr_t dst_addr;      // Destination MAC address
        addr_t src_addr;      // Source MAC address
        ethertype_t eth_type; // EtherType
    } hdr_t;

    //===================================
    // Derived Parameters
    //===================================
    localparam int HDR_BYTES = $bits(hdr_t) / 8;

endpackage : packet_eth_pkg
