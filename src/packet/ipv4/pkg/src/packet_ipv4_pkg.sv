// ============================================
// IPv4 definitions
// ============================================
package packet_ipv4_pkg;

    //===================================
    // Parameters
    //===================================
    localparam int VERSION_WID = 4;
    localparam int IHL_WID = 4;
    localparam int DSCP_WID = 6;
    localparam int ECN_WID = 2;
    localparam int TOTAL_LENGTH_WID = 16;
    localparam int ID_WID = 16;
    localparam int FLAGS_WID = 3;
    localparam int FRAGMENT_OFFSET_WID = 13;
    localparam int TTL_WID = 8;
    localparam int PROTOCOL_WID = 8;
    localparam int HEADER_CHECKSUM_WID = 16;
    localparam int ADDR_WID = 32;

    //===================================
    // Typedefs
    //===================================
    typedef enum logic [VERSION_WID-1:0] {
        VERSION_IPV4 = 4,
        VERSION_IPV6 = 6
    } version_t;

    typedef logic [IHL_WID-1:0]             ihl_t;
    typedef logic [DSCP_WID-1:0]            dscp_t;
    typedef logic [ECN_WID-1:0]             ecn_t;
    typedef logic [TOTAL_LENGTH_WID-1:0]    total_length_t;
    typedef logic [ID_WID-1:0]              id_t;
    typedef logic [FLAGS_WID-1:0]           flags_t;
    typedef logic [FRAGMENT_OFFSET_WID-1:0] fragment_offset_t;
    typedef logic [TTL_WID-1:0]             ttl_t;
    typedef logic [PROTOCOL_WID-1:0]        protocol_t;
    typedef logic [HEADER_CHECKSUM_WID-1:0] header_checksum_t;
    typedef logic [ADDR_WID-1:0]            addr_t;

    

    // MAC header specification
    typedef struct packed {
        version_t         version;         // Version (always equal to IPV4 for IPV4 packets)
        ihl_t             ihl;             // Internet Header Length
        dscp_t            dscp;            // Differentiated Services Code Point
        ecn_t             ecn;             // Explicit Congestion Notification
        total_length_t    total_length;    // Total Length
        id_t              id;              // Identification
        flags_t           flags;           // Flags
        fragment_offset_t fragment_offset; // Fragment Offset
        ttl_t             ttl;             // Time to Live
        protocol_t        protocol;        // Protocol
        header_checksum_t header_checksum; // Header Checksum
        addr_t            src_addr;        // Source IP address
        addr_t            dst_addr;        // Destination IP address
    } hdr_struct_t;

endpackage : packet_ipv4_pkg
