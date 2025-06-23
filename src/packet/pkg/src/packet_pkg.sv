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
