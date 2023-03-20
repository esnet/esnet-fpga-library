package packet_pkg;

    // Protocols
    typedef enum {
        PROTOCOL_NONE,
        PROTOCOL_ETHERNET,
        PROTOCOL_IPV4,
        PROTOCOL_IPV6,
        PROTOCOL_TCP,
        PROTOCOL_UDP
    } protocol_t;

    function automatic int get_header_size(input protocol_t protocol);
        case (protocol)
            PROTOCOL_ETHERNET: return packet_eth_pkg::HDR_BYTES;
            default: return 0;
        endcase
    endfunction

    function automatic string get_protocol_name(input protocol_t protocol);
        case (protocol)
            PROTOCOL_ETHERNET: return "Ethernet";
            default:           return "Raw";
        endcase
    endfunction
            
endpackage : packet_pkg
