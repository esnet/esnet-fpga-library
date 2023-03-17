package axi4l_pkg;

    // Typedefs
    typedef enum logic [1:0] {
        RESP_OKAY = 2'b00,
        RESP_EXOKAY = 2'b01,
        RESP_SLVERR = 2'b10,
        RESP_DECERR = 2'b11
    } resp_encoding_t;

    typedef union packed {
        resp_encoding_t encoded;
        bit [1:0]       raw;
    } resp_t;


    typedef enum {
        AXI4L_BUS_WIDTH_32,
        AXI4L_BUS_WIDTH_64
    } axi4l_bus_width_t;

    // Functions
    function automatic int get_axi4l_bus_width_in_bytes(input axi4l_bus_width_t bus_width);
        case (bus_width)
            AXI4L_BUS_WIDTH_32 : return 4;
            AXI4L_BUS_WIDTH_64 : return 8;
            default : return 4;
        endcase
    endfunction

endpackage : axi4l_pkg
