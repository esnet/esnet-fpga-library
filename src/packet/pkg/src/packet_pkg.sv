// ============================================
// PACKET
// ============================================
package packet_pkg;

    // ============================================
    // Protocols
    // ============================================
    typedef enum {
        PROTOCOL_NONE,
        PROTOCOL_ETHERNET,
        PROTOCOL_IPV4,
        PROTOCOL_IPV6,
        PROTOCOL_TCP,
        PROTOCOL_UDP
    } protocol_t;

    function automatic string get_protocol_name(input protocol_t protocol);
        case (protocol)
            PROTOCOL_ETHERNET: return "Ethernet";
            default:           return "Raw";
        endcase
    endfunction
            
    // ============================================
    // Packet size
    // ============================================
    // Packet sizes are carried in a fixed-width field, so that size-bearing
    // ports have a width that doesn't depend on an interface or module
    // parameter.  A component's own MAX_PKT_SIZE parameter still bounds its
    // storage; it must not exceed MAX_SIZE.
    //
    // Named SIZE_FIELD_WID rather than SIZE_WID to avoid silently shadowing
    // the local SIZE_WID declared by modules that wildcard-import this
    // package.
    localparam int SIZE_FIELD_WID = 16;
    localparam int MAX_SIZE = 2**SIZE_FIELD_WID - 1;  // 65535 bytes

    typedef logic [SIZE_FIELD_WID-1:0] size_t;

    // ============================================
    // Typedefs
    // ============================================
    typedef enum logic [2:0] {
        STATUS_UNDEFINED = 0,
        STATUS_OK = 1,
        STATUS_ERR = 2,
        STATUS_OFLOW = 3,
        STATUS_SHORT = 4,
        STATUS_LONG = 5
    } status_t;

    typedef enum {
        MUX_MODE_SEL  = 0,
        MUX_MODE_RR   = 1,
        MUX_MODE_LIST = 2
    } mux_mode_t;

endpackage : packet_pkg
